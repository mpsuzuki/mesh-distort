FT_CFLAGS = `pkg-config --cflags freetype2`
FT_LIBS = `pkg-config --libs freetype2`
MAGICK_CXXFLAGS = `pkg-config --cflags Magick++`
MAGICK_LIBS = `pkg-config --libs Magick++`
CFLAGS = $(FT_CFLAGS) -g3 -ggdb -O0
LDFLAGS =

all: magick.exe ft2aa.exe test-variable.exe

magick.exe: magick.cxx
	$(CXX) $(CXXFLAGS) $(MAGICK_CXXFLAGS) -o $@ $^ $(LDFLAGS) $(MAGICK_LIBS)

ft2aa.exe: ft2aa.c
	$(CC) $(CFLAGS) $(FT_CFLAGS) -o $@ $^ $(LDFLAGS) $(FT_LIBS)

test-variable.exe: test-variable.c
	$(CC) $(CFLAGS) $(FT_CFLAGS) -o $@ $^ $(LDFLAGS) $(FT_LIBS)
