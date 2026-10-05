#!/usr/bin/env python3
"""Plot the committed excerpts of the 2026-10-05 CODEC loopback captures.
Requires NumPy and Matplotlib; output is qpsk_loopback.png beside this script.
"""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parent
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11,
                     'axes.spines.top': False, 'axes.spines.right': False})
fig, axes = plt.subplots(2, 2, figsize=(11, 6.7), gridspec_kw={'height_ratios': [1.35, 1]})
for col, (wire, rate, color) in enumerate([('sc16', '7.68', '#2665a5'), ('sc8', '15.36', '#167a65')]):
    data = np.loadtxt(root / f'qpsk_{wire}_decisions.csv', delimiter=',', skiprows=1)
    waveform = np.loadtxt(root / f'qpsk_{wire}_waveform.csv', delimiter=',', skiprows=1)
    ax = axes[0, col]
    ax.scatter(data[:, 1], data[:, 2], s=8, alpha=.3, color=color, edgecolors='none')
    ax.axhline(0, color='#ced6df', lw=.7)
    ax.axvline(0, color='#ced6df', lw=.7)
    ax.set(xlim=(-.095, .095), ylim=(-.095, .095), aspect='equal',
           xlabel='I (normalized amplitude)', ylabel='Q (normalized amplitude)',
           title=f'{rate} MS/s · {wire}')
    ax.set_xticks([-.075, 0, .075]); ax.set_yticks([-.075, 0, .075])
    ax.grid(alpha=.2)
    ax = axes[1, col]
    sample = waveform[:, 0] - waveform[0, 0]
    ax.plot(sample, waveform[:, 1], color=color, label='I', lw=1.1)
    ax.plot(sample, waveform[:, 2], color='#cb7234', label='Q', lw=1.1, alpha=.9)
    ax.set(xlabel='Sample offset in capture excerpt', ylabel='Amplitude',
           xlim=(0, 255), ylim=(-.13, .13))
    ax.grid(alpha=.2); ax.legend(loc='upper right', ncol=2, frameon=False)
fig.suptitle('AD9361 digital loopback · measured QPSK captures', fontsize=16, weight='bold')
fig.text(.5, .016, 'Top: 2,000 symbol decisions per format. Bottom: 256 consecutive samples. Raw captured values; no gain or phase fit.',
         ha='center', fontsize=9, color='#4e5f72')
fig.tight_layout(rect=(0, .045, 1, .95))
fig.savefig(root / 'qpsk_loopback.png', dpi=160, facecolor='white')
