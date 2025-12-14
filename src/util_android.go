//go:build android
// +build android

package main

import (
    "io"
    "os"
)

// Log writer implementation
func NewLogWriter() io.Writer {
    return os.Stderr
}

// Message box implementation – for now, just print to stderr/logcat
func ShowInfoDialog(message, title string) {
    print(title + "\n\n" + message)
}

func ShowErrorDialog(message string) {
    print("I.K.E.M.E.N Error\n\n" + message)
}

// TTF font loading for Android.
func LoadFntTtf(f *Fnt, fontfile string, filename string, height int32) {
    // Search in local/game directories
    fileDir := SearchFile(filename, []string{fontfile, sys.motif.Def, "", "data/", "font/"})
    if fp := FileExist(fileDir); len(fp) != 0 {
        fileDir = fp
    } else {
        // Nothing found: apply some common aliases so Android builds
        // don't require the user to manually drop arial.ttf.
        if filename == "arial.ttf" || filename == "Arial.ttf" || filename == "ARIAL.TTF" {
            // Our assets ship Open Sans; use that as a substitute.
            alt := "font/Open_Sans/OpenSans-Regular.ttf"
            if fp2 := FileExist(alt); len(fp2) != 0 {
                fileDir = fp2
            } else {
                panic("TTF font not found: " + filename + " (also tried " + alt + ")")
            }
        } else {
            panic("TTF font not found: " + filename)
        }
    }

    if height == -1 {
        height = int32(f.Size[1])
    } else {
        f.Size[1] = uint16(height)
    }

    ttf, err := gfxFont.LoadFont(fileDir, height, int(sys.gameWidth), int(sys.gameHeight))
    if err != nil {
        panic(err)
    }
    f.ttf = ttf.(Font)

    // Create Ttf dummy palettes
    f.palettes = make([][256]uint32, 1)
    for i := 0; i < 256; i++ {
        f.palettes[0][i] = 0
    }
}