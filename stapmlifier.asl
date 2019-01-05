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

    // SMUF: SMU registers pointing to different power properties;
    //   0x03 : ? temps? (80, 74, 90)
    //   0x05 : STAPM Limit
    //   0x06 : PPT Fast Limit
    //   0x07 : PPT Slow Limit
    //   0x0B : Some energy limit, applied instantly
    //   0x0C : ? <10000 freezes uProf counters

    If ((Arg1 == Zero))
    {
      SMUF = 0x05
    }
    Else
    {
      SMUF = Arg1
    }

    // SMUFD: a value in SMU register, in miliwatts

    SMUD = ToInteger (Arg0)
    \_SB.ALIB (0x0C, XXAA)
  }
}
