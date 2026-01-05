#!/usr/bin/env python3
"""
FPGA Image Upload Tool

Uploads images to FPGA via UART for real-time processing.
Converts images to 640x480 grayscale and transmits pixel-by-pixel.

Author: Zeke Mohammed
Date: September 2025

Usage:
    python upload_image.py --port /dev/ttyUSB0 --image lena.png
    python upload_image.py --port COM3 --image test.jpg --preview
"""

import argparse
import time
import sys
from pathlib import Path

try:
    import serial
    import cv2
    import numpy as np
    from tqdm import tqdm
except ImportError as e:
    print(f"Error: Required package not installed: {e}")
    print("Install with: pip install -r requirements.txt")
    sys.exit(1)


class FPGAImageUploader:
    """Handles image upload to FPGA via UART"""

    # Image dimensions expected by FPGA
    IMAGE_WIDTH = 640
    IMAGE_HEIGHT = 480
    TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT

    def __init__(self, port, baud_rate=115200, timeout=5):
        """
        Initialize UART connection to FPGA

        Args:
            port: Serial port name (e.g., '/dev/ttyUSB0' or 'COM3')
            baud_rate: Communication speed (default: 115200)
            timeout: Serial timeout in seconds
        """
        self.port = port
        self.baud_rate = baud_rate

        try:
            self.ser = serial.Serial(
                port=port,
                baudrate=baud_rate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=timeout
            )
            print(f"✓ Connected to {port} at {baud_rate} baud")
        except serial.SerialException as e:
            print(f"✗ Failed to open serial port {port}: {e}")
            sys.exit(1)

    def load_and_prepare_image(self, image_path, preview=False):
        """
        Load image and convert to FPGA format

        Args:
            image_path: Path to input image
            preview: Show preview window before upload

        Returns:
            Processed image as numpy array (640x480 grayscale)
        """
        # Load image
        img = cv2.imread(str(image_path))
        if img is None:
            raise FileNotFoundError(f"Could not load image: {image_path}")

        print(f"✓ Loaded image: {image_path}")
        print(f"  Original size: {img.shape[1]}x{img.shape[0]}")

        # Convert to grayscale
        if len(img.shape) == 3:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            gray = img

        # Resize to 640x480
        resized = cv2.resize(gray, (self.IMAGE_WIDTH, self.IMAGE_HEIGHT),
                            interpolation=cv2.INTER_LINEAR)

        print(f"  Processed size: {self.IMAGE_WIDTH}x{self.IMAGE_HEIGHT} grayscale")

        # Preview
        if preview:
            cv2.imshow('Image to Upload (Press any key to continue)', resized)
            cv2.waitKey(0)
            cv2.destroyAllWindows()

        return resized

    def upload_image(self, image, show_progress=True):
        """
        Upload image to FPGA via UART

        Args:
            image: 640x480 grayscale numpy array
            show_progress: Show upload progress bar

        Returns:
            Upload duration in seconds
        """
        if image.shape != (self.IMAGE_HEIGHT, self.IMAGE_WIDTH):
            raise ValueError(f"Image must be {self.IMAGE_WIDTH}x{self.IMAGE_HEIGHT}")

        # Flatten image to 1D array (row-major order)
        pixels = image.flatten()

        # Clear any pending data
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

        print(f"\nUploading {self.TOTAL_PIXELS} pixels...")
        start_time = time.time()

        # Send pixels with progress bar
        if show_progress:
            for pixel in tqdm(pixels, desc="Upload", unit="pixels"):
                self.ser.write(bytes([pixel]))
        else:
            # Batch write for speed (if FPGA can handle it)
            chunk_size = 1024
            for i in range(0, len(pixels), chunk_size):
                chunk = pixels[i:i+chunk_size]
                self.ser.write(bytes(chunk))

        # Wait for transmission to complete
        self.ser.flush()

        duration = time.time() - start_time

        print(f"✓ Upload complete in {duration:.2f} seconds")
        print(f"  Data rate: {(self.TOTAL_PIXELS / duration):.0f} pixels/sec")
        print(f"  Bandwidth: {(self.TOTAL_PIXELS / duration / 1024):.2f} KB/s")

        return duration

    def close(self):
        """Close serial connection"""
        if hasattr(self, 'ser') and self.ser.is_open:
            self.ser.close()
            print("✓ Serial port closed")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Upload images to FPGA for real-time processing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Upload image with preview
  python upload_image.py --port /dev/ttyUSB0 --image test.jpg --preview

  # Upload at different baud rate
  python upload_image.py --port COM3 --image lena.png --baud 9600

  # Quick upload without progress
  python upload_image.py --port /dev/ttyUSB0 --image data.png --no-progress
        """
    )

    parser.add_argument(
        '--port', '-p',
        required=True,
        help='Serial port (e.g., /dev/ttyUSB0 or COM3)'
    )

    parser.add_argument(
        '--image', '-i',
        required=True,
        type=Path,
        help='Input image file (JPG, PNG, BMP, etc.)'
    )

    parser.add_argument(
        '--baud', '-b',
        type=int,
        default=115200,
        choices=[9600, 19200, 38400, 57600, 115200, 230400],
        help='Baud rate (default: 115200)'
    )

    parser.add_argument(
        '--preview',
        action='store_true',
        help='Show preview window before upload'
    )

    parser.add_argument(
        '--no-progress',
        action='store_true',
        help='Disable progress bar (faster upload)'
    )

    args = parser.parse_args()

    # Validate image file
    if not args.image.exists():
        print(f"Error: Image file not found: {args.image}")
        sys.exit(1)

    try:
        # Initialize uploader
        uploader = FPGAImageUploader(args.port, args.baud)

        # Load and prepare image
        image = uploader.load_and_prepare_image(args.image, args.preview)

        # Upload to FPGA
        uploader.upload_image(image, show_progress=not args.no_progress)

        print("\n✓ Upload successful! Check VGA output for processed image.")

    except KeyboardInterrupt:
        print("\n\n✗ Upload cancelled by user")
        sys.exit(1)

    except Exception as e:
        print(f"\n✗ Error during upload: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

    finally:
        uploader.close()


if __name__ == '__main__':
    main()
