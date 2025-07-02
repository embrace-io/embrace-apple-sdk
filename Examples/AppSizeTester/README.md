# SDK App Size Measurement Example

This project is designed to help measure the app size impact of integrating the Embrace SDK. It includes everything needed to assess both the compressed and uncompressed sizes of your app after the SDK integration.

## Methodology

Measuring the SDK size involves building different targets of the Test App:
- **AppSizeTester**: This target doesn't link the Embrace SDK. Building this target allows us to establish a baseline app size.
- **AppSizeTesterWithSDK**: As the name suggests, this target links the Embrace SDK. Building this target allows us to measure the incremental size impact of the SDK.

When creating an `.ipa` for each target, we also configure `xcodebuild` to export with the `thinning` option set to `<thin-for-all-variants>` to ensure we have thinned `.ipa` files.

For more information about this process, you can check [Apple's guide on reducing app size](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size).

> [!IMPORTANT] 
> This process attempts to _simulate_ the app thinning process using the tools provided by Apple. However, it's important to recognize that there may be differences in real environments. When an app is submitted to the App Store, the actual app thinning performed by Apple could lead to different results. We recommend to always test your app thoroughly in the App Store environment to understand its true impact. Check the About [SDK Size Measurement Accuracy](#about-sdk-size-measurement-accuracy)

## How to Use

To use this example project, you should follow these steps:

### Prerequisites

Ensure that you have the following tools installed on your system:
- **[Xcode](https://developer.apple.com/xcode/)**
- **[Tuist](https://github.com/tuist/tuist/)**: Needed to set up and generate the Xcode project and workspace.
- **[Bundler](https://bundler.io/)**: Used to manage Ruby dependencies and ensure that you can run `Fastlane`.

### Steps

1. Open your terminal.
2. Navigate to this folder.
3. Run the following commands:

    ```bash
    bundle install
    bundle exec fastlane calculate_sdk_size
    ```
When the process finishes, you will be able to see a report in the terminal like this one:
![image](https://github.com/user-attachments/assets/78191c20-3d35-4259-94c7-a11e986de2a3)

> [!NOTE]  
> **What's Compressed and Uncompressed Size?**
> 
> **Compressed Size** is the size of your app as it would be downloaded from an app store and it's crucial for understanding the download time and the initial storage impact on the user's device.
> 
> **Uncompressed Size** represents the actual size the app will occupy on a device once installed and it's important for understanding the total storage footprint of your app.


### About SDK Size Measurement Accuracy

The `calculate_sdk_size` lane estimates the size added by the SDK by generating two `.ipa` files:

- One without the SDK linked  
- One with the SDK minimally linked (via a dummy class to force inclusion)

It then calculates the difference between both apps using the **App Thinning Size Report** provided by Xcode. While this gives a reasonable approximation of the SDK's impact on final app size, it's important to note that the method has inherent **inaccuracies due to heuristics** used in the build and linking process.

#### An Example to Understand the Variability

To illustrate how this method behaves in practice, we ran the size calculation **21 times** (version `6.12.1`) using the exact same project configuration. The idea was to simulate a real-world scenario where nothing changes in the codebase, but the build system and linker may introduce small variations.

Below are the raw results from those 21 runs:

| Run # | Compressed (MB) | Uncompressed (MB) |
|-----|------------------|--------------------|
| 1   | 1.0648           | 2.9604             |
| 2   | 0.8857           | 2.5623             |
| 3   | 0.8857           | 2.5623             |
| 4   | 1.0658           | 2.9623             |
| 5   | 1.0658           | 2.9623             |
| 6   | 1.0658           | 2.9623             |
| 7   | 1.0648           | 2.9604             |
| 8   | 0.8857           | 2.5623             |
| 9   | 1.0658           | 2.9623             |
| 10  | 1.0648           | 2.9604             |
| 11  | 1.0658           | 2.9623             |
| 12  | 1.0658           | 2.9623             |
| 13  | 1.0648           | 2.9604             |
| 14  | 1.0658           | 2.9623             |
| 15  | 0.8848           | 2.5604             |
| 16  | 0.8848           | 2.5604             |
| 17  | 0.8848           | 2.5604             |
| 18  | 0.8848           | 2.5604             |
| 19  | 1.0648           | 2.9604             |
| 20  | 0.8848           | 2.5604             |
| 21  | 0.8857           | 2.5623             |

Here’s what we found:

- **Compressed size** ranged from **0.88 MB to 1.06 MB**  
- **Uncompressed size** ranged from **2.56 MB to 2.96 MB**

We then computed a few basic statistics to get a feel for the natural noise in the measurement:

| Metric             | Compressed       | Uncompressed     |
|--------------------|------------------|------------------|
| Mean               | 0.99 MB          | 2.79 MB          |
| Standard deviation | 0.089 MB         | 0.198 MB         |
| % Std. deviation   | 9.03%            | 7.10%            |

So even when nothing changes, the reported SDK size can vary by **up to ~9%**. That’s expected — small fluctuations are part of how the build system links symbols, strips unused code, and generates IPA contents.

