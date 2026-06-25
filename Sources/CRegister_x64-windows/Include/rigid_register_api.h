#ifndef RIGID_REGISTER_API_H
#define RIGID_REGISTER_API_H

// rigid_register_api.h
// 适配 C API
// - 输出使用调用方提供的 char buffer（out_json），库不分配/不释放
// - 返回值：
//     0  => out_json 缓冲区足够，已写入完整 JSON（NUL 结尾）
//    -1  => out_json 缓冲区不足或 out_json/out_cap 不合法：不写 out_json 的任何字节
//
// 说明：
// - 配准是否成功/失败，不由返回值表达，而由 JSON 内的 result.reg_ok 表达：
//     result.reg_ok == 1  => 配准成功
//     result.reg_ok == 0  => 配准失败（同时 result.error_code / result.err 给原因）
//
// 输出 JSON 顶层结构：
// {
//   "result": {...},   // reg_ok/error_code/err/raw_matches/inliers/...
//   "points": {...}    // 点对信息（失败时通常为 num_points=0, points=[]）
// }
// 输出 JSON 示例
// {
//   "result": {
//   "reg_ok": 1,
//   "error_code": 0,
//   "raw_matches": 443,
//   "inliers": 52,
//   "max_points": 10,
//   "num_points": 10,
//   "err": ""
// }
// ,
//   "points": {
//   "num_points": 10,
//   "points": [
//     {"x_fixed": 274.667, "y_fixed": 788.767, "x_moving": 558.678, "y_moving": 1314.786, "rotation": 15.985},
//     {"x_fixed": 499.568, "y_fixed": 1283.443, "x_moving": 1019.449, "y_moving": 1801.421, "rotation": 20.429},
//     {"x_fixed": 129.375, "y_fixed": 1231.971, "x_moving": 566.361, "y_moving": 1871.257, "rotation": 20.290},
//     {"x_fixed": 350.236, "y_fixed": 1071.862, "x_moving": 740.960, "y_moving": 1604.841, "rotation": 21.005},
//     {"x_fixed": 176.959, "y_fixed": 1060.884, "x_moving": 536.863, "y_moving": 1675.586, "rotation": 20.613},
//     {"x_fixed": 512.078, "y_fixed": 1118.732, "x_moving": 941.030, "y_moving": 1605.129, "rotation": 20.024},
//     {"x_fixed": 348.472, "y_fixed": 1236.208, "x_moving": 809.750, "y_moving": 1796.757, "rotation": 20.084},
//     {"x_fixed": 342.855, "y_fixed": 926.385, "x_moving": 674.788, "y_moving": 1460.260, "rotation": 19.651},
//     {"x_fixed": 409.332, "y_fixed": 843.102, "x_moving": 703.054, "y_moving": 1337.872, "rotation": 21.013},
//     {"x_fixed": 249.575, "y_fixed": 988.733, "x_moving": 581.018, "y_moving": 1572.333, "rotation": 21.022}
//   ]
// 
// }
// 输出角度单位为度（degree），旋转方向为顺时针为正，逆时针为负。
// 20度表示顺时针旋转20度，-90度表示逆时针旋转90度。
// 185度表示顺时针旋转185度，-185度表示逆时针旋转185度。

#include <stdint.h>
#include <stddef.h>
// RR_STATIC表示使用静态库
#if defined(RR_STATIC)
  #define RIGID_REGISTER_API
#else
  #if defined(_WIN32) || defined(_WIN64)
    #if defined(RIGID_REGISTER_API_BUILD)
      #define RIGID_REGISTER_API __declspec(dllexport)
    #else
      #define RIGID_REGISTER_API __declspec(dllimport)
    #endif
  #else
    #define RIGID_REGISTER_API __attribute__((visibility("default")))
  #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 使用 RGB24 像素输入执行刚性/相似配准。
 *
 * 输入为两张图像的 RGB24 raw 像素缓冲区（连续存储，按行主序）。
 * 像素排列顺序为：RGBRGBRGB...（每像素 3 字节）。
 *
 * @param fixed_pixels   Fixed 图像像素指针（RGB24，大小 fixed_width*fixed_height*3）。
 * @param fixed_width    Fixed 宽度。
 * @param fixed_height   Fixed 高度。
 * @param moving_pixels  Moving 图像像素指针（RGB24，大小 moving_width*moving_height*3）。
 * @param moving_width   Moving 宽度。
 * @param moving_height  Moving 高度。
 * @param max_points     最多输出点对数（内部会 clamp）。
 * @param out_json       输出：调用方提供 UTF-8 JSON 缓冲区（返回 0 时写入，NUL 结尾）。
 * @param out_cap        out_json 容量（字节数，包含最终 NUL 空间）。
 * @param out_dir        可选：调试输出目录（NULL 或 "" 表示不落盘；非空可输出调试文件）。
 *
 * @return
 *   0  => out_json 缓冲区足够，已写入 JSON（成功/失败看 JSON 内 result.reg_ok）
 *  -1  => out_json 缓冲区不足或 out_json/out_cap 不合法（不写 out_json 任何字节）
 */
RIGID_REGISTER_API int rigid_register_run_pixels_rgb24(
    const uint8_t* fixed_pixels,
    int fixed_width,
    int fixed_height,
    const uint8_t* moving_pixels,
    int moving_width,
    int moving_height,
    int max_points,
    char* out_json,
    size_t out_cap,
    const char* out_dir
);

/**
 * @brief 使用图像文件路径输入执行刚性/相似配准（内部读取图像）。
 *
 * @param fixed_path   Fixed 图像路径。
 * @param moving_path  Moving 图像路径。
 * @param max_points   最多输出点对数（内部会 clamp）。
 * @param out_json     输出：调用方提供 UTF-8 JSON 缓冲区（返回 0 时写入，NUL 结尾）。
 * @param out_cap      out_json 容量（字节数，包含最终 NUL 空间）。
 * @param out_dir      可选：调试输出目录（NULL 或 "" 表示不落盘；非空可输出调试文件）。
 *
 * @return
 *   0  => out_json 缓冲区足够，已写入 JSON（成功/失败看 JSON 内 result.reg_ok）
 *  -1  => out_json 缓冲区不足或 out_json/out_cap 不合法（不写 out_json 任何字节）
 */
RIGID_REGISTER_API int rigid_register_run_paths(
    const char* fixed_path,
    const char* moving_path,
    int max_points,
    char* out_json,
    size_t out_cap,
    const char* out_dir
);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // RIGID_REGISTER_API_H
