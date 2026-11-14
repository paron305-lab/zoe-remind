import 'dart:io';
import 'dart:math';

import 'package:llamadart/llamadart.dart';

/// Settings ng Zoe's Brain (Qwen sa phone).
/// Isang config para sa lahat ng phones — kapag binago dito, pareho sa lahat.
class InferenceConfig {
  InferenceConfig._();

  /// Ilang tokens ang kayang "tandaan" ni Qwen sa isang usapan.
  /// 2048 = sapat para sa system prompt + ilang turns, mababa ang RAM.
  static const contextSize = 2048;

  /// Default na haba ng sagot (tokens). Maikli lang para mabilis.
  static const defaultMaxTokens = 256;

  /// CPU threads: max 4 para hindi gamitin ang lahat ng cores
  /// (mas umiinit at mas mabagal kapag pati maliliit na cores).
  static int get threads => max(2, min(4, Platform.numberOfProcessors));

  /// CPU lang muna — experimental pa ang GPU (Vulkan) sa Android
  /// at iba-iba bawat phone. Same model + same settings sa lahat.
  static ModelParams get modelParams => ModelParams(
        contextSize: contextSize,
        device: ComputeDevice.cpu,
        gpuLayers: 0,
        numberOfThreads: threads,
        numberOfThreadsBatch: threads,
      );

  /// Sampling para sa normal na chat (Qwen non-thinking recommended).
  static GenerationParams chat({int? maxTokens}) => GenerationParams(
        maxTokens: maxTokens ?? defaultMaxTokens,
        temp: 0.7,
        topP: 0.8,
        topK: 20,
        penalty: 1.0,
      );

  /// Para sa JSON (intent extraction) — mas "sigurado", hindi creative.
  static GenerationParams json({int? maxTokens}) => GenerationParams(
        maxTokens: maxTokens ?? defaultMaxTokens,
        temp: 0.1,
        topP: 0.9,
        topK: 20,
        penalty: 1.0,
      );
}