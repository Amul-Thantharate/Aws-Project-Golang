package main

import (
	"fmt"
	"image"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/disintegration/imaging"
)

var (
	inputDir  = "./input"
	outputDir = "./output"
)

func main() {
	files, err := os.ReadDir(inputDir)
	if err != nil {
		log.Fatalf("Failed to read input directory: %v", err)
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		imageKey := file.Name()
		ext := strings.ToLower(filepath.Ext(imageKey))
		baseName := strings.TrimSuffix(filepath.Base(imageKey), ext)
		localPath := filepath.Join(inputDir, imageKey)

		fmt.Printf("📷 Processing file: %s\n", imageKey)

		img, err := imaging.Open(localPath)
		if err != nil {
			log.Printf("❌ Failed to open image: %v", err)
			continue
		}

		var wg sync.WaitGroup

		// Blur and upscale
		wg.Add(1)
		go func() {
			defer wg.Done()
			blurred := blurImage(img, 5.0)
			saveImage(blurred, fmt.Sprintf("%s_blurred%s", baseName, ext))

			width := img.Bounds().Dx()
			height := img.Bounds().Dy()
			for _, scale := range []int{2, 4} {
				upscaled := imaging.Resize(img, width*scale, height*scale, imaging.Lanczos)
				saveImage(upscaled, fmt.Sprintf("%s_upscale_%dx%s", baseName, scale, ext))
			}
		}()

		// Pixelation
		wg.Add(1)
		go func() {
			defer wg.Done()
			sizes := []int{8, 16, 32, 48, 64}
			for _, size := range sizes {
				err := pixelateImage(localPath, filepath.Join(outputDir, fmt.Sprintf("%s_pixelated-%dx%d%s", baseName, size, size, ext)), size, size)
				if err != nil {
					log.Printf("❌ Pixelation error: %v", err)
				}
			}
		}()

		wg.Wait()
		fmt.Println("✅ Processing complete for", imageKey)
	}
}

func blurImage(img image.Image, radius float64) image.Image {
	// Apply blur effect with the specified radius
	blurred := imaging.Blur(img, radius)
	return blurred
}

func saveImage(img image.Image, filename string) {
	outPath := filepath.Join(outputDir, filename)
	err := imaging.Save(img, outPath)
	if err != nil {
		log.Printf("❌ Failed to save image %s: %v", filename, err)
	} else {
		log.Printf("💾 Saved: %s", outPath)
	}
}

func pixelateImage(inputPath, outputPath string, width, height int) error {
	src, err := imaging.Open(inputPath)
	if err != nil {
		return fmt.Errorf("failed to open image: %w", err)
	}
	tmp := imaging.Resize(src, width, height, imaging.Linear)
	dst := imaging.Resize(tmp, src.Bounds().Dx(), src.Bounds().Dy(), imaging.NearestNeighbor)
	if err := imaging.Save(dst, outputPath); err != nil {
		return fmt.Errorf("failed to save pixelated image: %w", err)
	}
	log.Printf("💾 Pixelated: %s", outputPath)
	return nil
}
