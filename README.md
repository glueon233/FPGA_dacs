# FPGA_DAC — 基于 FPGA 的 Sigma-Delta 音频 DAC

## 概述

FPGA_DAC 是一个纯 FPGA 实现的音频 DAC 系统，接收 I2S 数字音频输入，经过 FIR 内插滤波与 Sigma-Delta 调制后输出 PDM 位流，再通过外部模拟低通滤波器重建音频信号。

## 系统架构

```
I2S 输入 (16bit@48kHz)
    ↓
IIS_RX — I2S 接收模块
    ↓  (16bit×1x)
FIR 0 — 1x → 2x 上采样
    ↓  (24bit×2x)
FIR 1 — 2x → 4x 上采样
    ↓  (24bit×4x)
FIR 2 — 4x → 64x 上采样
    ↓  (24bit×64x)
SDM — Sigma-Delta 调制器
    ↓  (1bit PDM)
外部 Sallen-Key 带通滤波器 (49Hz–24kHz)
    ↓
模拟音频输出
```

### 模块说明

| 模块 | 文件 | 说明 |
|------|------|------|
| `audio_top_v3` | `audio_top_v3.v` | 顶层模块 |
| `clk_wiz_0` | `clk_wiz_0.xci` | PLL，生成 24.576MHz 系统时钟 |
| `iis_rx` | `iis_rx.v` | I2S 从机接收，16bit，支持左右声道 |
| `fir_compiler_0` | `fir_compiler_0.xci` | 1x→2x 半带 FIR 内插滤波器 |
| `fir_compiler_1` | `fir_compiler_1.xci` | 2x→4x 半带 FIR 内插滤波器 |
| `fir_compiler_2` | `fir_compiler_2.xci` | 4x→64x FIR 内插滤波器 |
| `sdm_1o` | `sdm_1o.v` | 一阶 Sigma-Delta 调制器 |
| `sdm_2nd` | `sdm_2o_v2.v` | 二阶 Sigma-Delta 调制器 |
| `dsa_two` | `dsa_two.v` | 开源二阶 Sigma-Delta 调制器 |
| `ds_mash11` | `ds_mash11.v` | MASH 1-1 Sigma-Delta 调制器 |

## 硬件平台

- **FPGA**: Artix-7 (XC7A100T)
- **开发板**: AX7103 (或其他兼容板卡)
- **外部 DAC 滤波器**: 两级二阶 Sallen-Key 带通滤波器

## 外部模拟滤波器

PDM 输出需经模拟低通滤波恢复音频。本设计使用**两级二阶 Sallen-Key 带通滤波器**：

- 拓扑：Sallen-Key（压控电压源型）
- 阶数：四阶（两级二阶级联）
- 通带：**49 Hz – 24 kHz**
- 用途：滤除 PDM 高频噪声，还原高保真音频

## 管脚分配

| 管脚 | 信号 | 电平 |
|------|------|------|
| J19 | `clk` (50MHz 板载) | LVCMOS33 |
| F13 | `iis_bclk` | LVCMOS33 |
| E13 | `iis_lrclk` | LVCMOS33 |
| D14 | `iis_sdata` | LVCMOS33 |
| AA1 | `rst_n` | LVCMOS33 |
| A21 | `lout` (左声道 PDM) | LVCMOS33 |
| C20 | `rout` (右声道 PDM) | LVCMOS33 |
| M18/N18 | `leds[1:0]` | LVCMOS33 |

## 输出效果

PDM 输出经外部 Sallen-Key 滤波器后，可重建高质量的模拟音频波形，有效抑制带外噪声，通带内保持平坦响应。
