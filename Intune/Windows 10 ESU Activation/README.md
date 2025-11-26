
# Windows 10 ESU Activation

## How to Deploy ESU Detection and Remediation Scripts in Microsoft Intune
Intune’s **Scripts and Remediations** feature uses two scripts:

-   **Detection Script**: Checks if the device meets compliance (e.g., ESU is activated).
-   **Remediation Script**: Fixes the issue if the detection script reports non-compliance (e.g., installs and activates ESU keys).

---
### Creating a scheduled script
1. Download the *ESU_Detection.ps1* and  *ESU_Remediation.ps1* scripts.
2. Edit the top section of *ESU_Remediation.ps1* and insert your ESU keys, then save. 
3.  Sign in to the [*Microsoft Endpoint Manager Admin Center*](https://intune.microsoft.com/#home).
4.  Navigate to *Devices*, then *Scripts and remediations*. Click **Create** for a new package.
5. Enter a *Name* (e.g., “ESU Activation Check”), then click **Next**.
	- Optionally enter a description as well.
6. For the *Detection script file*, browse and select the *ESU_Detection.ps1*
7. For the *Remediation script file*, browse and select the *ESU_Remediation.ps1* (updated in step 2).
8. All remaining defaults are fine. Click **Next**.
9. Define your *Scope tags* as needed. If unsure, leave at the defaults. Then, click **Next**.
10. Click **Select groups to include** and assign to your Windows 10 device group. Then, click **Next**.
	- It is recommended to use dynamic security group for this with a membership rule of
	_(device.deviceOSVersion -notStartsWith "10.0.2") and (device.deviceManagementAppId -eq "0000000a-0000-0000-c000-000000000000")_
1. If you wish to run the schedule more than once per day, click **Daily** and adjust the frequency (i.e., Hourly, every 8 hours) and **Apply**. When finished, click **Next**.
1. On the *Review* screen, verify your selections and choose **Create**.

---
### Monitoring Results
To monitor the results, navigate to *Devices*, then *Scripts and remediations* and click on your script.

Review the Device Status section to confirm the deployment results. If you notice any devices listed under “Recurred” or “Failed,” it’s often due to those machines running an older version of Windows 10, such as 21H2, which doesn’t support ESU activation. To resolve this, address any Windows Update issues on those devices and upgrade them to Windows 10 version 22H2.