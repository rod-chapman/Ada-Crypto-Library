with AUnit.Assertions; 
with Crypto.Types;

package body Test.Base64 is
   use Crypto.Types;
  
--------------------------------------------------------------------------------
----------------------------- Register Tests -----------------------------------
--------------------------------------------------------------------------------
	
	procedure Register_Tests(T : in out Base64_Test) is
	   use Test_Cases.Registration;
	begin
	   Register_Routine(T,  Base64_Rest0_Test'Access,"Base64 Rest0 Test.");
	   Register_Routine(T,  Base64_Rest1_Test'Access,"Base64 Rest1 Test.");
	   Register_Routine(T,  Base64_Rest2_Test'Access,"Base64 Rest2 Test.");
	end Register_Tests;

--------------------------------------------------------------------------------
------------------------------ Name Base64 Test --------------------------------
--------------------------------------------------------------------------------

	function Name(T : Base64_Test) return Test_String is
	begin
		return new String'("Base64 Test");
	end Name;

------------------------------------------------------------------------------------
-------------------------------------- Test 1 --------------------------------------
------------------------------------------------------------------------------------

   procedure Base64_Rest0_Test(T : in out Test_Cases.Test_Case'Class) is
      use AUnit.Assertions; 
      use Base64;

      Input  : constant String := "any carnal pleasur";
      Output : constant Base64.Base64_String := "YW55IGNhcm5hbCBwbGVhc3Vy";
      Result : constant Base64.Base64_String := Base64.Encode_Base64( To_Bytes(Input) );
      Decoded: Bytes := Base64.Decode_Base64(Result);
   begin
      Assert(Output = Result, "Base64_Rest0_Test encode failed");  
    
      Assert(To_Bytes(Input) = Base64.Decode_Base64(Result), 
             			"Base64_Rest0_Test decode failed"); 
      
   end Base64_Rest0_Test;

------------------------------------------------------------------------------------
-------------------------------------- Test 2 --------------------------------------
------------------------------------------------------------------------------------


   procedure Base64_Rest1_Test(T : in out Test_Cases.Test_Case'Class) is
      use AUnit.Assertions; 
      use Base64;
      
      Input  : constant String := "any carnal pleasu";
      Output : constant Base64.Base64_String := "YW55IGNhcm5hbCBwbGVhc3U=";
      Result : constant Base64.Base64_String := Encode_Base64( To_Bytes(Input) );
      Decoded: Bytes := Base64.Decode_Base64(Result);
   begin
      
      Assert(Output = Result, "Base64_Rest1_Test encode failed"); 
      
      Assert(To_Bytes(Input) = Base64.Decode_Base64(Result), 
             			"Base64_Rest1_Test decode failed"); 
   end Base64_Rest1_Test;


------------------------------------------------------------------------------------
-------------------------------------- Test 3 --------------------------------------
------------------------------------------------------------------------------------


   procedure Base64_Rest2_Test(T : in out Test_Cases.Test_Case'Class) is
      use AUnit.Assertions; 
      use Base64;
      
      Input  : constant String := "any carnal pleas";
      Output : constant Base64.Base64_String := "YW55IGNhcm5hbCBwbGVhcw==";
      Result : constant Base64.Base64_String := Encode_Base64(To_Bytes(Input));
      Decoded: Bytes := Base64.Decode_Base64(Result);
   begin
      
      Assert(Output = Result, "Base64_Rest2_Test encode failed"); 
      Assert(Decoded = To_Bytes(Input), "Base64_Rest2_Test decode failed");
   end Base64_Rest2_Test;


end Test.Base64;
