# mpv-lines-meme-generator *for Windows*

![](example.png)

This script allows users to take screenshots in MPV, crop them to keep only the bottom portion, and stitch them together into a long vertical image, just like a meme of lines. It is designed for Windows operating systems and requires `ffmpeg` to function.

## Features

- Take multiple screenshots with the press of a key.
- Crop the bottom portion of the screenshots to create a unified long image.
- Stitch all cropped images together into a single output image.
- Customizable directory for saving images and height of cropped sections.

## Dependencies

- MPV Media Player
- FFmpeg (**ensure it is in your system's PATH**)

## Installation

1. Ensure you have [MPV](https://mpv.io/) and [FFmpeg](https://ffmpeg.org/) installed on your system.
2. Copy the script into your MPV scripts directory, typically found at:
   - `C:\Users\<YourUsername>\AppData\mpv\scripts\`
3. Edit the script to set the desired screenshot directory and cropping height.
4. Restart MPV.

## Usage

1. **Key Bindings**:
   - Press **`n`** to take a screenshot (can be pressed multiple times).
   - Press **`Ctrl+n`** to create the stitched image from the taken screenshots.

2. **Configuration**:
   - Update the `dir` option in the script to specify the directory where screenshots will be saved.
   - Adjust the `height` option to set the proportion of each image to keep (height from the bottom).

## Example Configuration

```lua
local options = {
    dir = "C:/Users/YourUsername/Documents/mpv/screenshots",
    height = 0.15,  -- Keep 15% of the image height from the bottom
}
```

## Acknowledgments

- Original concept and code by [Wanakachi](https://github.com/WatanabeChika).
- Thanks to the MPV community for their continuous support and contributions.

## Troubleshooting

- If you encounter issues with the script, ensure that the paths are correctly set and that `ffmpeg` is accessible from the command line.
- Check the MPV log for error messages related to the script.

