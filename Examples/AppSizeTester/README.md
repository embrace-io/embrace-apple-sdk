# SDK App Size Measurement Example

This project is designed to help measure the app size impact of integrating the Embrace SDK. It includes everything needed to assess both the compressed and uncompressed sizes of your app after the SDK integration.

## Methodology

Measuring the SDK size involves building different targets of the Test App:
- **AppSizeTester**: This target doesn't link the Embrace SDK. Building this target allows us to establish a baseline app size.
- **AppSizeTesterWithSDK**: As the name suggests, this target links the Embrace SDK. Building this target allows us to measure the incremental size impact of the SDK.

When creating an `.ipa` for each target, we also configure `xcodebuild` to export with the `thinning` option set to `<thin-for-all-variants>` to ensure we have thinned `.ipa` files.

For more information about this process, you can check [Apple's guide on reducing app size](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size).

> [!IMPORTANT] 
> This process attempts to _simulate_ the app thinning process using the tools provided by Apple. However, it's important to recognize that there may be differences in real environments. When an app is submitted to the App Store, the actual app thinning performed by Apple could lead to different results. We recommend to always test your app thoroughly in the App Store environment to understand its true impact.

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
