with AUnit.Assertions; use AUnit.Assertions;
with Crypto.Types;
with Crypto.Symmetric.KDF_SHA512Crypt;
use Crypto.Symmetric.KDF_SHA512Crypt;
with Crypto.Symmetric.KDF_SHA512Crypt.Testing;
use Crypto.Symmetric.KDF_SHA512Crypt.Testing;
with Crypto.Symmetric.Algorithm.SHA512;
use Crypto.Symmetric.KDF_SHA512Crypt.Base64;

package body Test.SHA512Crypt is
   use Crypto.Types;

   ----------------------------------------------------------------------------
   ---------------------------- Type - Declaration ----------------------------
   ----------------------------------------------------------------------------

   package S5C renames Crypto.Symmetric.KDF_SHA512Crypt;
   package SHA512 renames Crypto.Symmetric.Algorithm.SHA512;

   ---------------------------------------------------------------------------
   ------------------------ Register SHA512Crypt Test 1 ----------------------
   ---------------------------------------------------------------------------


   procedure Register_Tests(T : in out SHA512Crypt_Test) is
      use Test_Cases.Registration;
   begin
      Register_Routine(T, SHA512Crypt_Test_Add_Bytes'Access,
		       "SHA512Crypt Add Bytes");
      Register_Routine(T, SHA512Crypt_Test_Encryption'Access,
		       "SHA512Crypt Encryption / Decryption");
      Register_Routine(T, SHA512Crypt_Test_Exceptions'Access,
		       "SHA512Crypt Exceptions");
   end Register_Tests;

   --------------------------------------------------------------------------
   ------------------------- Name SHA512Crypt Test --------------------------
   --------------------------------------------------------------------------


   function Name(T : SHA512Crypt_Test) return Test_String is
   begin
      return new String'("SHA512Crypt Test");
   end Name;




---------------------------------- Start Tests -------------------------------


   procedure SHA512Crypt_Test_Add_Bytes(T : in out Test_Cases.Test_Case'Class) is

      Hash_Ideal : DW_Block512;
      Digest_Bytes : Bytes(0..127) := (others => 0);
      Digest_Bytes_Length : Natural := 0;
      Bytes_To_Add_A : constant Bytes(0..7) := (Others=>1);
      Bytes_To_Add_B : constant Bytes(0..63) := (Others=>2);
      Digest_Bytes_Ideal : Bytes(0..127) := (others => 0);

      Digest_Hash : Crypto.Symmetric.Algorithm.SHA512.Sha512_Context;
   begin


      Digest_Hash.Init;

      ----------------

      Hash_Ideal := Digest_Hash.Hash_Value;


      Add_Bytes_Testing(Bytes_To_Add        => Bytes_To_Add_A,
                    Digest_Bytes        => Digest_Bytes,
                    Digest_Bytes_Length => Digest_Bytes_Length,
                    Digest_Hash         => Digest_Hash);

      Assert(Digest_Hash.Hash_Value = Hash_Ideal, "SHA512Crypt failed.");
      Digest_Bytes_Ideal(0..7) := (others=>1);
      Assert(Digest_Bytes=Digest_Bytes_Ideal, "First Ideal failed");
      Assert(Digest_Bytes_Length = 8, "SHA512Crypt failed.");

      -----------------

      Hash_Ideal := Digest_Hash.Hash_Value;
      Add_Bytes_Testing(Bytes_To_Add        => Bytes_To_Add_B,
                    Digest_Bytes        => Digest_Bytes,
                    Digest_Bytes_Length => Digest_Bytes_Length,
                    Digest_Hash         => Digest_Hash);

      Assert(Digest_Hash.Hash_Value = Hash_Ideal, "SHA512Crypt failed.");
      Digest_Bytes_Ideal(8..71) := (others=>2);
      Assert(Digest_Bytes=Digest_Bytes_Ideal, "First Ideal failed");
      Assert(Digest_Bytes_Length = 72, "SHA512Crypt failed.");

      ---------------

      Hash_Ideal := Digest_Hash.Hash_Value;
      Digest_Bytes_Ideal(72..127) := (others=>2);
      SHA512.Round(Message_Block => To_DW_Block1024(B => Digest_Bytes_Ideal),
                   Hash_Value    => Hash_Ideal);
      Add_Bytes_Testing(Bytes_To_Add        => Bytes_To_Add_B,
                    Digest_Bytes        => Digest_Bytes,
                    Digest_Bytes_Length => Digest_Bytes_Length,
                    Digest_Hash         => Digest_Hash);

      Assert(Digest_Hash.Hash_Value = Hash_Ideal, "SHA512Crypt failed.");
      Digest_Bytes_Ideal(0..127) := (others=>0);
      Digest_Bytes_Ideal(0..7) := (others=>2);
      Assert(Digest_Bytes=Digest_Bytes_Ideal, "First Ideal failed");
      Assert(Digest_Bytes_Length = 8, "SHA512Crypt failed.");
   end SHA512Crypt_Test_Add_Bytes;
   
   
   --------------------------------------------------------------------------
   
   procedure SHA512Crypt_Test_Encryption(T : in out Test_Cases.Test_Case'Class)
   is
      Derived_Key, Ideal_Key : S5C.Base64.Base64_SHA512Crypt;
      Scheme : S5C.SHA512Crypt_KDF;
   begin


      --Truncating Salt missing

      Scheme.Initialize(Key_Length  => 86,  Round_Count => 5000);

      Scheme.Derive(Salt     => "saltstring",
		    Password => "Hello world!",
                    Key      => Derived_Key);
      Ideal_Key := "svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJuesI68u4OTLiBFdcbYEdFCoEOfaS35inz1";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");

      Scheme.Initialize(Key_Length  => 86, Round_Count => 10000);
      Scheme.Derive(Salt     => "saltstringsaltst",
                    Password => "Hello world!",
                    Key      => Derived_Key);
      Ideal_Key := "OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbHbbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v.";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");

      Scheme.Initialize(Key_Length  => 86, Round_Count => 5000);
      Scheme.Derive(Salt     => "toolongsaltstrin",
                    Password => "This is just a test",
                    Key      => Derived_Key);
      Ideal_Key := "lQ8jolhgVRVhY4b5pZKaysCLi0QBxGoNeKQzQ3glMhwllF7oGDZxUhx1yxdYcz/e1JSbq3y6JMxxl8audkUEm0";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");


      Scheme.Initialize(Key_Length  => 86, Round_Count => 77777);
      Scheme.Derive(Salt     => "short",
                    Password => "we have a short salt string but not a short password",
                    Key      => Derived_Key);
      Ideal_Key := "WuQyW2YR.hBNpjjRhpYD/ifIw05xdfeEyQoMxIXbkvr0gge1a1x3yRULJ5CCaUeOxFmtlcGZelFl5CxtgfiAc0";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");


      Scheme.Initialize(Key_Length  => 86, Round_Count => 123456);
      Scheme.Derive(Salt     => "asaltof16chars..",
                    Password => "a short string",
                    Key      => Derived_Key);
      Ideal_Key := "BtCwjqMJGx5hrJhZywWvt0RLE8uZ4oPwcelCjmw2kSYu.Ec6ycULevoBK25fs2xXgMNrCzIMVcgEJAstJeonj1";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");


      Scheme.Initialize(Key_Length  => 86, Round_Count => 10);
      Scheme.Derive(Salt     => "roundstoolow",
                    Password => "the minimum number is still observed",
                    Key      => Derived_Key);
      Ideal_Key := "kUMsbe306n21p9R.FRkW3IGn.S9NPN0x50YhH1xhLsPuWGsUSklZt58jaTfF4ZEQpyUNGc0dqbpBYYBaHHrsX.";

      Assert(Derived_Key = Ideal_Key, "Fail at SHA512Crypt Test");
   end SHA512Crypt_Test_Encryption;
   
   --------------------------------------------------------------------------

   procedure SHA512Crypt_Test_Exceptions(T : in out Test_Cases.Test_Case'Class)
   is
      DWB1 : constant DW_Block1024 := (others=>0);
      DWB2 : constant DW_Block1024 := (others=>2);
      
      Hash1 : DW_Block512;
      Hash2 : DW_Block512;

      SHA512One : Crypto.Symmetric.Algorithm.SHA512.Sha512_Context;
      SHA512Two : Crypto.Symmetric.Algorithm.SHA512.Sha512_Context;

   begin
      SHA512One.Init;
      SHA512Two.Init;

      Hash1 := SHA512One.Final_Round(Last_Message_Block  => DWB1,
                                     Last_Message_Length => DWB1'Length/8);


      Hash2 := SHA512Two.Final_Round(Last_Message_Block  => DWB2,
                                     Last_Message_Length => DWB2'Length/8);
   end SHA512Crypt_Test_Exceptions;
   
end Test.SHA512Crypt;
