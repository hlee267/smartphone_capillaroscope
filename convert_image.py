


import os
import rawpy
import subprocess
from skimage import io
import traceback

def extract_preview_with_exiftool(image_path):
    try:
        output_path = image_path[:-4] + ".jpg"
        result = subprocess.run([
            'exiftool',
            '-b',
            '-PreviewImage',
            image_path
        ], capture_output=True)
        
        if result.returncode == 0 and result.stdout:
            with open(output_path, 'wb') as f:
                f.write(result.stdout)
            print("Extracted preview with exiftool:", output_path)
        else:
            print("exiftool could not extract preview from:", image_path)
    except Exception as e:
        print("Fallback via exiftool failed for", image_path)
        traceback.print_exc()


def main():
    root_dir = input("Enter 'images*' folders names: ").strip()
    if not os.path.isdir(root_dir):
        print(f"Error: '{root_dir}' is not a valid directory.")
        return

    images = []
    for root, dirs, files in os.walk(root_dir):
        for fname in files:
            if fname.lower().endswith('.dng'):
                images.append(os.path.join(root, fname))

    if not images:
        print("No DNG files found in:", root_dir)
        return

    print(f"\nFound {len(images)} DNG file(s). Starting conversion...\n")

    for image in images:
        try:
            with rawpy.imread(image) as raw:
                rgb = raw.postprocess()
                tif_path = image[:-4] + '.tif'
                io.imsave(tif_path, rgb)
                print("rawpy success:", tif_path)
        except rawpy.LibRawFileUnsupportedError:
            print("rawpy failed (unsupported format). Trying exiftool preview extraction...")
            extract_preview_with_exiftool(image)
        except Exception:
            print(f"Unexpected error processing {image} with rawpy:")
            traceback.print_exc()

    print(f"\n Conversion complete. Processed {len(images)} file(s).")

if __name__ == "__main__":
    main()

