#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MULTIPLE_MASTERS_H

#include <stdio.h>
#include <stdint.h>

void draw_bitmap_as_ascii(FT_Bitmap *bitmap)
{
    for (unsigned int y = 0; y < bitmap->rows; y++) {
        for (unsigned int x = 0; x < bitmap->width; x++) {
            unsigned char pixel = bitmap->buffer[y * bitmap->pitch + x];
            putchar(pixel > 128 ? '#' : ' ');
        }
        putchar('\n');
    }
}

int main(int argc, char** argv)
{
    FT_Library  library;
    FT_Face     face;
    FT_MM_Var  *mm_var = NULL;
    FT_Fixed*   coords = NULL;
    const char* font_path = argv[1];
    FT_UInt     font_pixel_size = strtoul(argv[2], NULL, 0);
    FT_UShort   font_variable_wght = strtoul(argv[3], NULL, 0);

    FT_Init_FreeType(&library);
    FT_New_Face(library, font_path, 0, &face);  // Replace path

    // Set pixel size
    FT_Set_Pixel_Sizes(face, 0, font_pixel_size);

    // Get variation info
    FT_Get_MM_Var(face, &mm_var);

    // Set wght axis
    coords = (FT_Fixed*)malloc(mm_var->num_axis * sizeof(FT_Fixed));
    for (int i = 0; i < mm_var->num_axis; ++i) {
        coords[i] = mm_var->axis[i].def;  // Default
        if (mm_var->axis[i].tag == FT_MAKE_TAG('w','g','h','t')) {
            coords[i] = font_variable_wght << 16;  // weight in 16.16 format
        }
    }
    FT_Set_Var_Design_Coordinates(face, mm_var->num_axis, coords);

    // Render glyph 'A'
    FT_UInt glyph_index = FT_Get_Char_Index(face, 'A');
    FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT | FT_LOAD_NO_BITMAP);
    FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);

    draw_bitmap_as_ascii(&face->glyph->bitmap);

    // Clean up
    FT_Done_MM_Var(library, mm_var);
    FT_Done_Face(face);
    FT_Done_FreeType(library);

    return 0;
}
