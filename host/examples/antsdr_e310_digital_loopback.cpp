// SPDX-License-Identifier: GPL-3.0-or-later
// FPGA or CODEC digital loopback. The driver isolates the RF transmit path.
#include <uhd/usrp/multi_usrp.hpp>
#include <uhd/types/metadata.hpp>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <complex>
#include <exception>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <thread>
#include <vector>

// Counter-based deterministic symbol sequence, never wrapped at packet boundaries.
static std::complex<float> qpsk_sample(size_t sample)
{
    uint32_t x = uint32_t(sample / 32) + 1;
    x ^= x >> 16; x *= 0x7feb352dU;
    x ^= x >> 15; x *= 0x846ca68bU; x ^= x >> 16;
    return {(x & 1) ? 0.07f : -0.07f, (x & 2) ? 0.07f : -0.07f};
}

int main(int argc, char** argv)
{
    try {
        if (argc < 5 || argc > 9) {
            std::cerr << "Usage: antsdr_e310_digital_loopback ADDRESS SECONDS TONE_SIGN OUTPUT.fc32 [fpga|codec] [RATE] [tone|qpsk] [sc16|sc8]\n";
            return 2;
        }
        const double seconds = std::stod(argv[2]);
        const int sign = std::stoi(argv[3]);
        const std::string mode = argc >= 6 ? argv[5] : "fpga";
        const double rate = argc >= 7 ? std::stod(argv[6]) : 1.92e6;
        const std::string pattern = argc >= 8 ? argv[7] : "tone";
        const std::string wire_format = argc >= 9 ? argv[8] : "sc16";
        if (wire_format != "sc16" && wire_format != "sc8")
            throw std::runtime_error("wire format must be sc16 or sc8");
        if (pattern != "tone" && pattern != "qpsk") throw std::runtime_error("invalid pattern");
        if (!(rate >= 1.92e6 && rate <= 15.36e6) || seconds*rate > 60e6)
            throw std::runtime_error("rate must be 1.92..15.36 MSPS; capture at most 60M samples");
        if (mode != "fpga" && mode != "codec") throw std::runtime_error("invalid loopback mode");
        if (!(seconds >= 0.1 && seconds <= 30) || (sign != 1 && sign != -1))
            throw std::runtime_error("seconds must be 0.1..30; tone sign must be +1 or -1");
        const double pi = std::acos(-1.0);
        auto usrp = uhd::usrp::multi_usrp::make(
            std::string("type=ant,addr=") + argv[1]
            + ",master_clock_rate=30.72e6,e310_" + mode + "_loopback=1");
        usrp->set_rx_rate(rate);
        usrp->set_tx_rate(rate);
        if (std::abs(usrp->get_rx_rate()-rate)>1 || std::abs(usrp->get_tx_rate()-rate)>1)
            throw std::runtime_error("unexpected sample rate coercion");
        uhd::stream_args_t args("fc32", wire_format);
        args.channels = {0};
        auto rx = usrp->get_rx_stream(args);
        auto tx = usrp->get_tx_stream(args);
        const size_t count = size_t(rate*seconds);
        std::vector<std::complex<float>> samples(count), wave(8192);
        for (size_t n=0; n<wave.size(); ++n)
            wave[n] = std::polar(0.1f, float(sign*2*pi*(n%64)/64));
        usrp->set_time_now(uhd::time_spec_t(0.0));
        uhd::stream_cmd_t cmd(uhd::stream_cmd_t::STREAM_MODE_NUM_SAMPS_AND_DONE);
        cmd.num_samps = count;
        cmd.stream_now = false;
        cmd.time_spec = uhd::time_spec_t(0.5);
        rx->issue_stream_cmd(cmd);
        std::atomic<bool> stop{false};
        size_t sent = 0;
        std::exception_ptr tx_error;
        std::thread sender([&] {
            try {
                uhd::tx_metadata_t md;
                md.start_of_burst = true;
                md.has_time_spec = true;
                md.time_spec = uhd::time_spec_t(0.5);
                // Keep TX alive beyond the finite RX capture, including filter transients.
                const size_t total = count + 32768;
                while (sent < total && !stop) {
                    const size_t offset = pattern == "tone" ? sent % wave.size() : 0;
                    const size_t n = std::min(wave.size()-offset, total-sent);
                    if (pattern == "qpsk")
                        for (size_t j=0; j<n; ++j) wave[j] = qpsk_sample(sent+j);
                    md.end_of_burst = sent+n == total;
                    const size_t done = tx->send(wave.data()+offset, n, md, 2.0);
                    if (!done) throw std::runtime_error("TX send timeout");
                    sent += done;
                    md.start_of_burst = md.has_time_spec = false;
                }
                if (stop) {
                    md.start_of_burst = md.has_time_spec = false;
                    md.end_of_burst = true;
                    tx->send(wave.data(), 0, md, 0.1);
                }
            } catch (...) { tx_error = std::current_exception(); }
        });
        size_t received = 0, rx_errors = 0, gaps = 0;
        double first_stamp = -1, expected = -1;
        std::exception_ptr rx_error;
        try {
            while (received < count) {
                uhd::rx_metadata_t md;
                const size_t n = rx->recv(samples.data()+received,
                    std::min(size_t(16384), count-received), md, 2.0);
                if (md.error_code != uhd::rx_metadata_t::ERROR_CODE_NONE) {
                    ++rx_errors;
                    throw std::runtime_error("RX metadata: " + md.strerror());
                }
                if (!n || !md.has_time_spec)
                    throw std::runtime_error("missing RX samples or timestamp");
                const double stamp = md.time_spec.get_real_secs();
                if (first_stamp < 0) first_stamp = stamp;
                if (expected >= 0 && std::abs(stamp-expected)*rate > 0.51) ++gaps;
                expected = stamp+n/rate;
                received += n;
            }
        } catch (...) { rx_error = std::current_exception(); stop = true; }
        sender.join();
        if (rx_error) {
            rx->issue_stream_cmd(uhd::stream_cmd_t(uhd::stream_cmd_t::STREAM_MODE_STOP_CONTINUOUS));
            std::rethrow_exception(rx_error);
        }
        if (tx_error) std::rethrow_exception(tx_error);
        size_t async_errors = 0, acks = 0;
        uhd::async_metadata_t amd;
        const auto deadline = std::chrono::steady_clock::now()+std::chrono::seconds(2);
        while (std::chrono::steady_clock::now() < deadline) {
            if (tx->recv_async_msg(amd, 0.1)) {
                if (amd.event_code == uhd::async_metadata_t::EVENT_CODE_BURST_ACK) ++acks;
                else { ++async_errors; std::cerr << "TX async event: " << int(amd.event_code) << '\n'; }
            } else if (acks) break;
        }
        if (mode == "codec" && !usrp->get_mboard_sensor("e310_loopback_isolated").to_bool())
            throw std::runtime_error("RF isolation verification failed after streaming");
        std::ofstream raw(argv[4], std::ios::binary);
        raw.write(reinterpret_cast<const char*>(samples.data()), samples.size()*sizeof(samples[0]));
        if (!raw) throw std::runtime_error("cannot save capture");
        const double startup_us = (first_stamp-0.5)*1e6;
        const bool transport_pass = !rx_errors && !gaps && !async_errors && acks == 1
            && startup_us>=0 && startup_us<=100;
        std::cout << std::setprecision(10)
            << "mode=" << mode << " pattern=" << pattern << " wire_format=" << wire_format << " RF_TX="
            << (mode == "fpga" ? "chain_disabled" : "DAC_mixer_powerdown") << " rate=" << rate
            << " tx_samples=" << sent << " rx_samples=" << received
            << " rx_errors=" << rx_errors << " timestamp_gaps=" << gaps
            << " tx_async_errors=" << async_errors << " burst_acks=" << acks
            << " first_rx_time=" << first_stamp << " startup_latency_us=" << startup_us << '\n';
        if (pattern == "qpsk") {
            // Find one fixed integer delay from a short preamble, then check
            // the remaining sequence without resynchronizing or phase rotation.
            int best_delay = 0;
            double best_score = -1;
            for (int delay=-512; delay<=1024; ++delay) {
                double dot=0, xx=0, yy=0;
                for (size_t s=256; s<512; ++s) {
                    const auto x = std::complex<double>(qpsk_sample(s*32+16));
                    const auto y = std::complex<double>(samples[s*32+16+delay]);
                    dot += std::real(std::conj(x)*y); xx += std::norm(x); yy += std::norm(y);
                }
                const double score=dot/std::sqrt(std::max(xx*yy,1e-30));
                if (score>best_score) { best_score=score; best_delay=delay; }
            }
            size_t bits=0, errors=0;
            double xx=0, yy=0, xy=0;
            for (size_t s=512; s*32+16+1024<samples.size()-8192; ++s) {
                const auto x=std::complex<double>(qpsk_sample(s*32+16));
                const auto y=std::complex<double>(samples[s*32+16+best_delay]);
                errors += ((x.real()>0)!=(y.real()>0)) + ((x.imag()>0)!=(y.imag()>0));
                bits += 2; xx += std::norm(x); yy += std::norm(y); xy += std::real(std::conj(x)*y);
            }
            const double gain=xy/xx;
            const double evm=std::sqrt(std::max(0.0,yy-xy*xy/xx)/std::max(xy*xy/xx,1e-30));
            const bool pass=transport_pass && best_score>0.99 && bits>0 && errors==0 && evm<0.05;
            std::cout << "qpsk_delay_samples=" << best_delay << " preamble_correlation=" << best_score
                << " checked_bits=" << bits << " bit_errors=" << errors << " gain=" << gain
                << " decision_evm=" << evm << '\n' << (pass ? "PASS" : "FAIL") << std::endl;
            return pass ? 0 : 1;
        }
        // Fit the expected complex tone and its IQ-swapped (conjugate) image.
        const size_t begin = 8192, end = ((samples.size()-8192)/64)*64;
        const double usable = end-begin;
        std::complex<double> wanted{}, image{}, lag{};
        double energy = 0;
        for (size_t n=begin; n<end; ++n) {
            const std::complex<double> x(samples[n]);
            const auto osc = std::polar(1.0, sign*2*pi*(n%64)/64);
            wanted += x*std::conj(osc);
            image += x*osc;
            energy += std::norm(x);
            if (n>begin) lag += x*std::conj(std::complex<double>(samples[n-1]));
        }
        wanted /= usable; image /= usable; energy /= usable;
        const double coherent = std::norm(wanted)/std::max(energy, 1e-30);
        const double image_db = 10*std::log10(std::norm(wanted)/std::max(std::norm(image), 1e-30));
        const double measured = std::arg(lag)*rate/(2*pi);
        // The framer timestamps the first DDC output, after the timed RX
        // command starts the DSP pipeline. Record this latency separately;
        // this test allows <=100 us and requires exact subsequent continuity.
        const bool pass = transport_pass && coherent>0.99
            && image_db>40 && std::abs(measured-sign*rate/64)<30;
        std::cout << "expected_tone_hz=" << sign*rate/64 << " measured_tone_hz=" << measured
            << " amplitude=" << std::abs(wanted) << " coherent_power_fraction=" << coherent
            << " image_rejection_db=" << image_db << '\n'
            << (pass ? "PASS" : "FAIL") << std::endl;
        return pass ? 0 : 1;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << std::endl;
        return 1;
    }
}
