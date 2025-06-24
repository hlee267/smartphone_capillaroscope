import os
import rawpy
from skimage import io

def main():
    # Prompt the user for the root directory to search
    root_dir = input("Enter 'images*' folders names: ").strip()
    if not os.path.isdir(root_dir):
        print(f"Error: '{root_dir}' is not a valid directory.")
        return

    # Gather all .dng files inside folders starting with "images"
    images = []
    for root, dirs, files in os.walk(root_dir):
        for fname in files:
            if fname.lower().endswith('.dng'):
                images.append(os.path.join(root, fname))

    if not images:
        print("No DNG files found in any 'images*' folders under:", root_dir)
        return

    for image in images:
        with rawpy.imread(image) as raw:
            rgb = raw.postprocess(gamma=(1,1), 
                                  use_camera_wb=True, 
                                  output_color=rawpy.ColorSpace.raw, 
                                  no_auto_scale=True, 
                                  highlight_mode=rawpy.HighlightMode.Ignore, 
                                  no_auto_bright=True, 
                                  output_bps=16)
            io.imsave((image[0:-4]+'.tif'), rgb)

    print(f"\nConversion complete. Processed {len(images)} file(s).")

if __name__ == "__main__":
    main()