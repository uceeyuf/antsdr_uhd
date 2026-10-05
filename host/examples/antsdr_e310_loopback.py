#!/usr/bin/env python3
"""One-device, one-channel cabled loopback for the experimental old E310 port.
Requires the Python bindings built from this antsdr_uhd fork and NumPy.
Connect TX1 to RX1 through suitable attenuation before running.
"""
import argparse
import threading
import time
import numpy as np
import uhd


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--addr', required=True)
    p.add_argument('--freq', type=float, required=True, help='RF frequency in Hz')
    p.add_argument('--rate', type=float, default=1.92e6)
    p.add_argument('--seconds', type=float, default=1)
    p.add_argument('--tx-gain', type=float, default=0)
    p.add_argument('--rx-gain', type=float, default=0)
    p.add_argument('--output', default='e310_loopback.npz')
    a = p.parse_args()
    if a.rate <= 0 or a.seconds <= 0:
        p.error('rate and seconds must be positive')
    usrp = uhd.usrp.MultiUSRP('type=ant,addr=' + a.addr)
    usrp.set_clock_source('internal')
    usrp.set_time_source('internal')
    usrp.set_rx_rate(a.rate, 0)
    usrp.set_tx_rate(a.rate, 0)
    rate = usrp.get_rx_rate(0)
    if abs(rate - usrp.get_tx_rate(0)) > 1 or abs(rate - a.rate) > 1:
        raise RuntimeError('RX/TX rate coercion mismatch; choose a supported common rate')
    usrp.set_rx_freq(uhd.types.TuneRequest(a.freq), 0)
    usrp.set_tx_freq(uhd.types.TuneRequest(a.freq), 0)
    usrp.set_rx_gain(a.rx_gain, 0)
    usrp.set_tx_gain(a.tx_gain, 0)
    usrp.set_rx_antenna('RX2', 0)  # Legacy UHD name for the dedicated receive connector.
    sa = uhd.usrp.StreamArgs('fc32', 'sc16')
    sa.channels = [0]
    rx, tx = usrp.get_rx_stream(sa), usrp.get_tx_stream(sa)
    usrp.set_time_now(uhd.types.TimeSpec(0))
    start = 0.5
    cmd = uhd.types.StreamCMD(uhd.types.StreamMode.start_cont)
    cmd.stream_now = False
    cmd.time_spec = uhd.types.TimeSpec(start)
    rx.issue_stream_cmd(cmd)
    # Exactly 64 samples per tone cycle; repeated blocks preserve phase.
    wave = (0.05 * np.exp(2j*np.pi*np.arange(4096)/64)).astype(np.complex64)[None, :]
    stop = threading.Event()
    errors = []

    def transmit():
        md = uhd.types.TXMetadata()
        md.start_of_burst = True
        md.has_time_spec = True
        md.time_spec = uhd.types.TimeSpec(start)
        offset = 0
        try:
            while not stop.is_set():
                n = tx.send(wave[:, offset:], md, 1.0)
                if n <= 0:
                    raise RuntimeError('TX send timeout')
                md.start_of_burst = False
                md.has_time_spec = False
                offset = (offset + n) % wave.shape[1]
        except Exception as exc:
            errors.append(str(exc))
        finally:
            md.start_of_burst = False
            md.has_time_spec = False
            md.end_of_burst = True
            try:
                tx.send(np.empty((1, 0), np.complex64), md, 1.0)
            except Exception as exc:
                errors.append(str(exc))

    worker = threading.Thread(target=transmit, daemon=True)
    worker.start()
    size = int(rate*a.seconds)
    capture = np.empty(size, dtype=np.complex64)
    md = uhd.types.RXMetadata()
    pos, expected = 0, None
    deadline = time.monotonic() + a.seconds + 5
    try:
        while pos < size:
            if errors or time.monotonic() > deadline:
                raise RuntimeError('; '.join(errors) or 'capture deadline exceeded')
            n = rx.recv(capture[None, pos:min(size, pos+16384)], md, 2.0)
            if md.error_code != uhd.types.RXMetadataErrorCode.none:
                raise RuntimeError(md.strerror())
            if not n or not md.has_time_spec:
                raise RuntimeError('Missing samples or RX timestamp')
            stamp = md.time_spec.get_real_secs()
            if expected is not None and abs(stamp-expected)*rate > 1.1:
                raise RuntimeError('Discontinuous RX timestamps')
            expected = stamp+n/rate
            pos += n
    finally:
        stop.set()
        rx.issue_stream_cmd(uhd.types.StreamCMD(uhd.types.StreamMode.stop_cont))
        worker.join(3)
    if worker.is_alive() or errors:
        raise RuntimeError('; '.join(errors) or 'TX worker did not stop')
    amd = uhd.types.TXAsyncMetadata()
    while tx.recv_async_msg(amd, 0.1):
        if amd.event_code != uhd.types.TXMetadataEventCode.burst_ack:
            raise RuntimeError('TX asynchronous error: ' + str(amd.event_code))
    usable = capture[min(4096, size//4):]
    nfft = min(65536, usable.size)
    if nfft < 1024:
        raise RuntimeError('Capture too short for spectrum check')
    spectrum = np.abs(np.fft.fft(usable[:nfft]*np.hanning(nfft)))**2
    peak = int(np.argmax(spectrum))
    peak_hz = np.fft.fftfreq(nfft, 1/rate)[peak]
    np.savez(a.output, samples=capture, rate=rate, frequency=a.freq, tone=rate/64)
    # Spectral check supplements transport/timestamp checks; this is not an EVM test.
    if abs(peak_hz-rate/64) > 3*rate/nfft:
        raise RuntimeError(f'Expected tone {rate/64:g} Hz, measured {peak_hz:g} Hz; capture saved')
    print(f'PASS: {pos} RX samples, continuous timestamps, TX/RX tone {peak_hz:g} Hz; {a.output}')


if __name__ == '__main__':
    main()
