#ifndef DUMMY_PNG_H
#define DUMMY_PNG_H

#include <stdio.h>

#define PNG_LIBPNG_VER_STRING "1.6.37"
#define PNG_ALL_FILTERS 0
#define PNG_COLOR_TYPE_PALETTE 1
#define PNG_COLOR_TYPE_RGB 2
#define PNG_RESOLUTION_METER 1
#define PNG_INTERLACE_ADAM7 1

#define Z_DEFAULT_COMPRESSION 0
#define Z_DEFAULT_STRATEGY 0
#define Z_DEFLATED 0

typedef void* png_structp;
typedef void** png_structpp;
typedef void* png_infop;
typedef void** png_infopp;
typedef void* png_voidp;
typedef void* png_error_ptr;
typedef unsigned char* png_bytep;
typedef char* png_charp;
typedef unsigned int png_uint_32;
typedef int png_int_32;

typedef struct {
    unsigned char red, green, blue;
} png_color;

typedef struct {
    int key, text;
} png_text;

static inline png_structp png_create_write_struct(const char* ver_string, png_voidp e_ptr, png_error_ptr e_fn, png_error_ptr w_fn) { return NULL; }
static inline png_infop png_create_info_struct(png_structp png_ptr) { return NULL; }
static inline void png_destroy_write_struct(png_structpp png_ptr_ptr, png_infopp info_ptr_ptr) {}
static inline void png_init_io(png_structp png_ptr, FILE* fp) {}
static inline void png_set_compression_level(png_structp png_ptr, int level) {}
static inline void png_set_compression_buffer_size(png_structp png_ptr, int size) {}
static inline void png_set_filter(png_structp png_ptr, int method, int filters) {}
static inline void png_set_compression_mem_level(png_structp png_ptr, int mem_level) {}
static inline void png_set_compression_window_bits(png_structp png_ptr, int window_bits) {}
static inline void png_set_compression_strategy(png_structp png_ptr, int strategy) {}
static inline void png_set_compression_method(png_structp png_ptr, int method) {}
static inline void png_set_IHDR(png_structp png_ptr, png_infop info_ptr, png_uint_32 width, png_uint_32 height, int bit_depth, int color_type, int interlace_type, int compression_type, int filter_type) {}
static inline void png_set_PLTE(png_structp png_ptr, png_infop info_ptr, const png_color* palette, int num_palette) {}
static inline void png_set_gAMA(png_structp png_ptr, png_infop info_ptr, double file_gamma) {}
static inline void png_set_pHYs(png_structp png_ptr, png_infop info_ptr, png_uint_32 res_x, png_uint_32 res_y, int unit_type) {}
static inline void png_set_text(png_structp png_ptr, png_infop info_ptr, const png_text* text_ptr, int num_text) {}
static inline void png_write_info(png_structp png_ptr, png_infop info_ptr) {}
static inline void png_write_row(png_structp png_ptr, png_bytep row) {}
static inline void png_write_end(png_structp png_ptr, png_infop info_ptr) {}

#endif
#define PNG_INTERLACE_NONE 0
#define PNG_COMPRESSION_TYPE_DEFAULT 0
#define PNG_FILTER_TYPE_DEFAULT 0
