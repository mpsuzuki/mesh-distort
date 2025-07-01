FT_CFLAGS = `pkg-config --cflags freetype2`
FT_LIBS = `pkg-config --libs freetype2`
CFLAGS = $(FT_CFLAGS) -g3 -ggdb -O0 -fkeep-inline-functions
LDFLAGS = $(FT_LIBS)

ft2aa.exe: ft2aa.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

