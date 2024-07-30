# Compare Folders

This is a simple tool to compare two folders for equality. I wrote it for a really specific use case where i copy a folder from one btrfs/zfs volume to another. The Data as it is read back will always be correct, as it is checked via checksum, but there might be added invalid bits during copy if there is no ECC memory. To check for perfect equality afterwards, this tool can be used.

## Why dart?

Because i like dart and the main bottleneck is the HDD/SSD, not essentially the CPU. So, why doing it the hard way with C/C++?

## Equality?
The tool will check if both folders contain exactly the same files and folders, will recurse into them and check the files there too. Only if all files are bit-per-bit equal and all filenames and folder names too, then the operation will succeed.

## Usage

Either directly run it or use dart to compile. Then run with

    ./folder_compare.exe -a /path/to/folderA -b /path/to/folderB

You will see an update every 5 seconds.
