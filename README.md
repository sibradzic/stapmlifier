# stapmlifier

Customized ACPI method for overriding mobile AMD APU STAPM values

## Introduction

On recent AMD mobile (and possibly desktop as well) APUs, system firmware is in control of most SoC power-related functions, such as configurable TPM parameters, socket power limits, thermal throttling & co. One such parameter that is often used on notebooks with AMD APUs is known as STAPM, which is used in attempt to control something known as T-Skin. Essentially, APU will be allowed to run at its specified max TDP for a limited time, after which it will get throttled to a TDP value supposedly supported by notebook cooling solution as well as notebook chassis heat dissipation capabilities, and all that in order to prevent notebook chassis over-heating (see https://fuse.wikichip.org/news/1596/hot-chips-30-amd-raven-ridge/2/ for more details).

This chassis & cooling solution TDP limit is controlled by a variable called 'STAPM Limit', measured in watts, and the choice for its default is entirely in notebook vendor hands. Unfortunately, notebook vendors usually do pretty poor job on setting the appropriate default value for STAPM limit, either due to lack of proper thermal-performance tests and/or due to being conservative (in terms of allowed max dissipated heat, nobody wants a customer complaining 'my notebook is damn too hot'). Even worse, most of the notebook vendors do not even allow choosing the STAPM limit in BIOS. In few instances, user has option to select between 'quiet' and 'performance' modes, where the mode will result in different STAPM Limit setting, but it is a mystery to what actual TDP wattage these modes set the limits to.

Fortunately, some smart people (credis to u/MinecraftAddict131) figured out that STAPM variables can be controlled via ACPI. However, methods that control them is vendor and model specific, and sometime even BIOS-revision specific. Some people figured out how to modify their notebook DSDT ACPI tables, in a very model-specific way, to change STAPM limit default. The default ACPI tables can be overridden by some boot-loaders, resulting in custom ACPI logic being executed by OS. However, on some notebooks, despite existing STAPM control methods, no known ACPI events will trigger any of them.
So far, it has been observed that ACPI STAPM control methods have something in common, they all rely on **ALIB** ACPI method, ehich is usually defined in one of the ACPI SSDT tables. This method is setting appropriate APU SoC DPTCi (Dynamic Power and Thermal Configuration Interface) parameters, which has direct implications on STAPM behavior.

Overriding DSDT tables is a tedious and complicated endeavor, regardless of OS & boot-loader involved. Fortunately, Linux has a built-in mechanism to inject a custom ACPI method on runtime, allowing using **ALIB** ACPI method in any desired manner (see https://www.kernel.org/doc/Documentation/acpi/method-customizing.txt for details). This mini project is an attempt to create universal and vendor-independent way to control mobile APU STAPM variables via custom ACPI method.

## How does it work

### Requirements

In order to make this possible we need some tools and kernel modules (the names are Debian ecosystem specific, similar tools should exist on all major distros):

 * **acpica-tools**: Intel ACPI Compiler/Disassembler (thanks Intel ;)
 * **debugfs**: in order to expose /sys/kernel/debug/acpi
 * **custom_method**: kernel module that allows runtime ACPI method customization
 * **acpi-call-dkms**: kernel module that allows generating custom ACPI calls on runtime

Looks like Ubuntu is not providing **custom_method** module on their stock kernels (thanks @hyc for the warning), but only on PPA-builds. Also, Ubuntu seems to be suffering from a bug related to debugfs file permission, introduced by [this distro patch](https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/cosmic/commit/fs/debugfs/file.c?id=a1ba65da9ceae481c154bfd1a2c1550e4566d986) (Well, Fedora suffers from it too). The module can be built from source with some effort:

    # Enable source packages
    sudo cp /etc/apt/sources.list /root/sources.list
    sudo sed -i '/deb-src/s/^# //' /etc/apt/sources.list && sudo apt update

    # Download modules source
    KVER=$(uname -r)
    sudo apt build-dep linux-modules-$(uname -r)
    apt source linux-modules-$(uname -r)

    cd linux-${KVER%%-*}
    cp /boot/config-$(uname -r) .config
    cp /usr/src/linux-headers-$(uname -r)/Module.symvers ./

    # Ubuntu kernel version string gymnastics (there must be better way than this?)
    sed -i 's|SUBLEVEL = .*|SUBLEVEL = 0|' Makefile
    sed -i "s|.*\(CONFIG_LOCALVERSION=\).*|\1\"-${KVER#*-}\"|" .config
    sed -i "s|.*\(CONFIG_LOCALVERSION_AUTO\).*|\1=n|" .config
    sed -i "s|.*\(CONFIG_ACPI_CUSTOM_METHOD\).*|\1=m|" .config

    make kernelrelease
    make prepare
    make M=scripts

    # workaround for debugfs file permission bug
    TAB="$(printf '\t')"
    patch -p1 << EOF
    --- a/drivers/acpi/custom_method.c
    +++ b/drivers/acpi/custom_method.c
    @@ -78,6 +78,7 @@
     static const struct file_operations cm_fops = {
     ${TAB}.write = cm_write,
     ${TAB}.llseek = default_llseek,
    +${TAB}.open = simple_open,
     };
     
     static int __init acpi_custom_method_init(void)
    EOF

    make M=drivers/acpi custom_method.ko

    sudo cp drivers/acpi/custom_method.ko /lib/modules/$(uname -r)/kernel/drivers/acpi/
    sudo depmod
    sudo modprobe custom_method

### Manually overriding STAPM vars

First, we compile our custom ACPI method from source:

    iasl -vw 6084 stapmlifier.asl

Next step is to make sure kernel debugfs is mounted (if not mounted already) and **custom_method** module is loaded. This will allow modifying existing or creating new ACPI methods on runtime:

    sudo mount -t debugfs none /sys/kernel/debug
    sudo modprobe custom_method

After all kernel bits are ready, we can inject our custom ACPI method:

    sudo cp stapmlifier.aml /sys/kernel/debug/acpi/custom_method

Finally, we can use a functionality of **acpi_call** kernel module to call our custom ACPI method, starting by loading the module:

    sudo modprobe acpi_call

Now we can call our custom ACPI mettod, named "\STPM", with some parameters of our choosing. For example, to set **STAPM Limit** to 25W:

    echo "\STPM 25000" | sudo tee --append /proc/acpi/call

First parameter is wattage, given in miliwatts. Second optional parameter can be used, that determines which DPTCi parameter will be modified. For example:

    echo "\STPM 30000 0x06" | sudo tee --append /proc/acpi/call

Note the **0x06** parameter, this will select particular DPTCi parameter that controls **PPT Fast Limit**, and here we will set it to 30W. As our previous example indicates, this second parameter can be omitted, in case of which the method will default to **0x05** which is a parameter controlling **STAPM Limit**. 

### Known DPTCi parameters:

This info was derived from https://support.amd.com/techdocs/44065_arch2008.pdf, by reading some DSDT implememntations as well as some experiments on real hardware:

 * **0x01**: STAPM Time Constant in seconds (default 200)
 * **0x02**: Skin Control Scalar, in percent (default 100)
 * **0x03**: Thermal Control Limit, in Celsius (float 32?)
 * **0x04**: ? Package Power Limit (2x DWORD, one for AC, one for DC)?
 * **0x05**: STAPM Limit
 * **0x06**: Package Power Target (PPT) Fast Limit (XFR power limit?)
 * **0x07**: Package Power Target (PPT) Slow Limit

### Helper script

One can also use a convenient helper script to set STAPM parameters, for example:

    ./set-stapm.sh STAPM-limit 25

### Observing STAPM vars in Linux

For this, one will need AMD's uProf for Linux. In order to monitor power-related metric in Linux, one needs to compile and load **AMDPowerProfiler** kernel module, distributed within the uProf archive or package. However, on recent kernels this module fails to compile, to fix this follow this guide (assuming you're on Ubuntu 18.10, and have **AMDuProf_Linux_x64_2.0.493.tar.gz** available in **~/Downloads**, as well as stapmlifier code at **~/stapmlifier**):

    sudo apt install linux-headers-generic build-essential libelf-dev
    tar -zxf ~/Downloads/AMDuProf_Linux_x64_2.0.493.tar.gz
    cd AMDuProf_Linux_x64_2.0.493/bin

    MODULE_NAME=AMDPowerProfiler
    MODULE_VERSION=$(cat AMDPowerProfilerVersion) # 7.02
    mkdir $MODULE_NAME-$MODULE_VERSION
    tar -zxf AMDPowerProfilerDriverSource.tar.gz
    cd $MODULE_NAME-$MODULE_VERSION

Patch it with provided patch file (needed on Linux >=4.18) & compile it:

    patch -p1 < ~/stapmlifier/uprof.patch
    make

    sudo mkdir -p /lib/modules/`uname -r`/kernel/drivers/extra
    sudo cp AMDPowerProfiler.ko /lib/modules/`uname -r`/kernel/drivers/extra/
    sudo depmod
    sudo modprobe AMDPowerProfiler

The driver requires manual char node creation:

    VER=$(cat /proc/AMDPowerProfiler/device)
    sudo mknod /dev/AMDPowerProfiler -m 666 c $VER 0


## Disclaimer

Modifying STAPM vars may expose one's expensive notebook to loads and temperatures that it was not designed for, and under extreme conditions may cause hardware failures. Anything you may be doing by following these lines is being done entirely on you own risk.
