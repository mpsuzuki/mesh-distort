#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_FREETYPE_H

FT_Library  ft_lib;

int get_num_bits_by_pixel_mode(FT_Pixel_Mode  pxl_mode)
{
  switch (pxl_mode) {
    case FT_PIXEL_MODE_NONE:  return 0;
    case FT_PIXEL_MODE_MONO:  return 1;
    case FT_PIXEL_MODE_GRAY:  return 8;
    case FT_PIXEL_MODE_GRAY2: return 2;
    case FT_PIXEL_MODE_GRAY4: return 4;
    case FT_PIXEL_MODE_LCD  : return 8;
    case FT_PIXEL_MODE_LCD_V: return 8;
    case FT_PIXEL_MODE_BGRA:  return 32;
    default:
      return -1;
  }
}

int get_pixel_be_from_buffer(unsigned char*  column_pixels,
                             int             bitwidth,
                             int             icolumn)
{
  int j = 0;
  int r = 0;

  if (bitwidth < 8) {
    int ibyte = (icolumn * bitwidth) / 8;
    int ishift = 8 - bitwidth - ((icolumn * bitwidth) % 8);
    char bytemask = ~(0xFF << bitwidth);
    r = (column_pixels[ibyte] >> ishift) & bytemask;
  } else {
    int bytewidth = (bitwidth / 8);

    for (j = 0; j < bytewidth; j++) {
      r |= column_pixels[(icolumn * bytewidth) + j] << (bytewidth - j - 1);
    }
  }
  return r;
}


int dump_glyph_bitmap_as_aa(FT_Bitmap*  bitmap_ptr,
                            FT_Int      bearing_top,
                            FT_Int      bearing_left)
{
  int ix, iy, ic;
  const int nbits_pp = get_num_bits_by_pixel_mode(bitmap_ptr->pixel_mode);
  for (iy = 0; iy < bitmap_ptr->rows; iy++) {
    unsigned char* column_pixels = bitmap_ptr->buffer + (iy * bitmap_ptr->pitch);
    for (ix = 0; ix < bitmap_ptr->width; ix++) {
      int r = get_pixel_be_from_buffer(column_pixels, nbits_pp, ix);
      if (0 < r) {
         printf("%2X", r);
      } else {
         printf("  ");
      }
    }
    printf("\n");
  }
}

char*      path_font = NULL;
char*      path_image = NULL;
char       ft_char = 0;
FT_UInt32  ft_ucs = 0;
FT_UInt32  ft_gid = 0;
int        height = 64;
int        width = 64;
FT_Render_Mode ft_render_mode = FT_RENDER_MODE_NORMAL;

void parse_argv(int argc, char** argv)
{
  while (1) {
    int this_option_optind = optind ? optind : 1;
    int option_index = 0;
    static struct option long_options[] = {
      { "char",    required_argument, 0, 'c' },
      { "font",    required_argument, 0, 'f' },
      { "gid",     required_argument, 0, 'g' },
      { "mono",    no_argument,       0, 'm' },
      { "output",  required_argument, 0, 'o' },
      { "uhex",    required_argument, 0, 'u' },
      { "verbose", no_argument,       0, 'v' },
      { "height",  no_argument,       0, 'H' },
      { "width",   no_argument,       0, 'W' },
      { 0, 0, 0, 0 }
    };

    const int c = getopt_long(argc, argv, "c:f:g:mo:u:vH:V:", long_options, &option_index);
    if (c < 0)
      break;

    switch (c) {
      case 'c': ft_char    = optarg[0]; break;
      case 'f': path_font  = optarg; break;
      case 'g': ft_gid     = strtol(optarg, NULL, 0); break;
      case 'm': ft_render_mode = FT_RENDER_MODE_MONO; break;
      case 'o': path_image = optarg; break;
      case 'u': ft_ucs     = strtol(optarg + 2, NULL, 16); break;
      case 'H': height     = strtol(optarg, NULL, 0); break;
      case 'W': width      = strtol(optarg, NULL, 0); break;
      default: exit(-1);
    }
  }
}

int main(int argc, char** argv)
{
  FT_Error      ft_err;
  FT_Face       ft_face;
  FT_GlyphSlot  ft_slot;
  FT_UInt32     ft_gid;
  FT_Vector     origin;
  
  parse_argv(argc, argv);


  ft_err = FT_Init_FreeType( &ft_lib );
  if (ft_err) return ft_err;

  ft_err = FT_New_Face( ft_lib, path_font, 0, &ft_face );
  if (ft_err) return ft_err;

  ft_err = FT_Set_Pixel_Sizes( ft_face, 0, height );
  if (ft_err) return ft_err;

  if (ft_char != 0 && ft_gid == 0)
    ft_gid = FT_Get_Char_Index( ft_face, ft_char );

  ft_err = FT_Load_Glyph( ft_face, ft_gid, 0 );
  if (ft_err) return ft_err;

  ft_err = FT_Render_Glyph( ft_face->glyph, ft_render_mode );
  if (ft_err) return ft_err;

  dump_glyph_bitmap_as_aa( &(ft_face->glyph->bitmap),
                             ft_face->glyph->bitmap_top,
                             ft_face->glyph->bitmap_left );

/*
  ft_err = FT_Done_Glyph( ft_face->glyph );
  if (ft_err) return ft_err;
 */

  ft_err = FT_Done_Face( ft_face );
  if (ft_err) return ft_err;

/*
  ft_err = FT_Done_Library( ft_lib );
  if (ft_err) return ft_err;
 */

  ft_err = FT_Done_FreeType( ft_lib );
  return ft_err;
}
