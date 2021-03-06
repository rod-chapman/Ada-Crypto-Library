with Test.Skein;
with Test.SHA1;
with Test.SHA256;
with Test.SHA384;
with Test.SHA512;
with Test.Whirlpool;

package body Test.Suite_Hash_Function is
   use AUnit.Test_Suites;

   Result:				aliased Test_Suite;
   Secure_Hash_Algorithm1_Test:		aliased Test.SHA1.SHA_Test;
   Secure_Hash_Algorithm2_256_Test: 	aliased Test.SHA256.SHA_Test;
   Secure_Hash_Algorithm2_384_Test: 	aliased Test.SHA384.SHA_Test;
   Secure_Hash_Algorithm2_512_Test: 	aliased Test.SHA512.SHA_Test;
   Skein_Test:           		aliased Test.Skein.Skein_Test;
   Whirlpool_Test: 			aliased Test.Whirlpool.SHA_Test;
  
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Add_Test(Result'Access, Secure_Hash_Algorithm1_Test'Access);
      Add_Test(Result'Access, Secure_Hash_Algorithm2_256_Test'Access);
      Add_Test(Result'Access, Secure_Hash_Algorithm2_384_Test'Access);
      Add_Test(Result'Access, Secure_Hash_Algorithm2_512_Test'Access);
      Add_Test(Result'Access, Skein_Test'Access);   
      Add_Test(Result'Access, Whirlpool_Test'Access);
      
      return Result'Access;
   end Suite;
end Test.Suite_Hash_Function;
