DefinitionBlock ("", "DSDT", 1, "", "", 0x000000002)
{
  Method (\STPM, 2, Serialized)
  {
    // XXAA: 7-byte buffer object that is passed to ALIB method

    Name (XXAA, Buffer (0x07){})
    CreateWordField (XXAA, Zero, SSZE)
    CreateByteField (XXAA, 0x02, SMUF)
    CreateDWordField (XXAA, 0x03, SMUD)
    SSZE = 0x07

    // SMUF: DPTCi parameters pointing to different power properties;
    //   0x01 : STAPM Time Constant in seconds (default 200)
    //   0x02 : Skin Control Scalar, in percent (default 100)
    //   0x03 : Thermal Control Limit, in Celsius (float 32?)
    //   0x04 : ? Package Power Limit (2x DWORD, one for AC, one for DC)?
    //   0x05 : STAPM Limit
    //   0x06 : Package Power Target (PPT) Fast Limit (boost limit, miliwatts)
    //   0x07 : Package Power Target (PPT) Slow Limit (power limit, miliwatts)
    //   0x08 : ?
    //   0x09 : ?
    //   0x0A : ? setting anything here instantly drops STAPM limit to 0?
    //   0x0B : VRM Current Limit (miliampers)
    //   0x0C : Max VRM Current Limit (CPU+iGPU power budget, miliampers)

    If ((Arg1 == Zero))
    {
      SMUF = 0x05
    }
    Else
    {
      SMUF = Arg1
    }

    // SMUFD: a value in SMU register, mostly in miliwatts

    SMUD = ToInteger (Arg0)
    \_SB.ALIB (0x0C, XXAA)
  }
}
