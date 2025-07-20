#include <Magick++.h>
#include <iostream>

using namespace std;
using namespace Magick;

int main(int argc, char **argv) {
    // Initialize ImageMagick
    InitializeMagick(*argv);

    // Define image dimensions
    const int width = 100;
    const int height = 100;

    // Create a dummy RGBA array
    unsigned char arr[height][width][4];
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            arr[y][x][0] = x % 256;        // Red
            arr[y][x][1] = y % 256;        // Green
            arr[y][x][2] = (x + y) % 256;  // Blue
            arr[y][x][3] = 128;            // Alpha (semi-transparent)
        }
    }

    // Create an image with RGBA support
    Image image(Geometry(width, height), Color(0, 0, 0, QuantumRange)); // Transparent background
    image.type(TrueColorMatteType); // Enable alpha channel

    // Fill image pixels from array
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            Color pixel;
            pixel.redQuantum(arr[y][x][0] * QuantumRange / 255);
            pixel.greenQuantum(arr[y][x][1] * QuantumRange / 255);
            pixel.blueQuantum(arr[y][x][2] * QuantumRange / 255);
            pixel.alphaQuantum((255 - arr[y][x][3]) * QuantumRange / 255); // Inverted alpha

            image.pixelColor(x, y, pixel);
        }
    }

    // Write image to file
    try {
        image.write("output.png");
        cout << "Image saved as output.png" << endl;
    } catch (Exception &error_) {
        cerr << "Error writing image: " << error_.what() << endl;
        return 1;
    }

    return 0;
}

