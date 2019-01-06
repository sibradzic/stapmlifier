#!/bin/bash

set -e

function usage() {
  echo "Usage:"
  echo "  $0 <parameter> <value>"
  echo "    where <parameter> is one of:"
  echo "      STAPM-limit" 
  echo "      PPT-fast" 
  echo "      PPT-slow" 
  echo "      Temp-target"
  echo "    and <value> is in watts or celsius:"
  echo "      25"
  echo "Examples:"
  echo "  $0 STAPM-limit 25"
  echo "  $0 Tepm-target 85"
}

case $1 in
  "STAPM-limit")
    REGISTER=0x05
    VALUE=${2}000
    UNIT=W
    ;;
  "PPT-fast")
    REGISTER=0x06
    VALUE=${2}000
    UNIT=W
    ;;
  "PPT-slow")
    REGISTER=0x07
    VALUE=${2}000
    UNIT=W
    ;;   
  "Temp-target")
    REGISTER=0x03
    VALUE=${2}
    UNIT=C
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ ! $2 =~ ^[0-9]+$ ]]; then
  usage
  exit 2
fi

echo "Compiling custom ACPI method"
iasl -vw 6084 stapmlifier.asl

echo "Injecting custom ACPI method into debugfs"
sudo modprobe custom_method
sudo cp stapmlifier.aml /sys/kernel/debug/acpi/custom_method

echo "Setting $1 to $2 $UNIT"
sudo modprobe acpi_call
echo "\STPM $VALUE $REGISTER" | sudo tee --append /proc/acpi/call

echo "Done"
