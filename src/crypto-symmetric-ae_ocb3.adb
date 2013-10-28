with Ada.Containers.Indefinite_Vectors;
with Ada.Text_IO;
with Crypto.Types;

package body Crypto.Symmetric.AE_OCB3 is

   -- useful constants
   Zero_Bytes: constant Bytes(0..(Bytes_Per_Block - 1)) := (others => 0);
   Zero_Block: constant Block := To_Block_Type(Zero_Bytes);
   -- If Store_Internally = True, every Ciphertext block will be stored in
   -- the Vector Masked_Plaintext
   Store_Internally: Boolean := False;

   --Hui
   L_Star, L_Dollar : Block := Zero_Block;  
   Nonce_Init : Bytes := Zero_Bytes;
   AD : Block := Zero_Block; -- no AD, Hash(AD) returns zeros();

   -- package initializations
   package Vectors is new Ada.Containers.Indefinite_Vectors(Index_Type   => Positive,
							    Element_Type => Bytes);
   Masked_Plaintext: Vectors.Vector;

   -----------------------------------------------------------------
   ----
   ---- auxiliary functions and procedures
   ----
   -----------------------------------------------------------------

   -- This procedure takes out the first element of the Vector
   -- Masked_Plaintext and deletes it.
   procedure Read_Masked_Plaintext(B : out Bytes;
                         Count : out Natural) is
      use Ada.Containers;
   begin
      if Masked_Plaintext.Length = 0 then
         Count := 0;
      else
         if Masked_Plaintext.First_Element'Length = Bytes_Per_Block then
            B := Masked_Plaintext.First_Element;
            Count := Bytes_Per_Block;
         else
            declare
               Temp: Bytes := Zero_Bytes;
            begin
               Temp(Temp'First..Masked_Plaintext.First_Element'Length-1) := Masked_Plaintext.First_Element;
               B := Temp;
               Count := Masked_Plaintext.First_Element'Length;
            end;
         end if;
         Masked_Plaintext.Delete_First;
      end if;
   end Read_Masked_Plaintext;

   -----------------------------------------------------------------

   function Double_S(S: Block) return Block is
      use Crypto.Types;
      Result : Bytes(0..(Bytes_Per_Block - 1)) := To_Bytes(S);
      --Tmp : Bytes := Zero_Bytes;
      Tmp_1 : B_Block128 := To_B_Block128(To_Bytes(S));
   begin
      if Result(0) < 128 then
         Result:=To_Bytes( Shift_Left(Tmp_1,1));
      else
         Result :=  To_Bytes(Shift_Left(Tmp_1,1)) xor 2#1000_0111#;
      end if;
      return To_Block_Type(Result);
   end Double_S;
   
   -----------------------------------------------------------------
   -- This procedure should be run before encryption and decryption.
   procedure Setup(Key: in  Key_Type;
                     A: in out Block_Array) is
      Tmp : Bytes(0 .. Bytes_Per_Block - 1);
   begin
      BC.Encrypt(Zero_Block, L_Star); --L_*
      Tmp := To_Bytes(L_Star);
      Ada.Text_IO.Put("L_*");
      for i in Tmp'Range loop
          Ada.Text_IO.Put(Tmp(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;

      L_Dollar := Double_S(L_Star);   --L_$
      Tmp := To_Bytes(L_Dollar);
      Ada.Text_IO.Put("L_$");
      for i in Tmp'Range loop
          Ada.Text_IO.Put(Tmp(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;

      A(-1) := Double_S(L_Dollar); -- (-1) refers to L[0] in the docu
      for i in 0..31 loop
          A(i) := Double_S(A(i-1));
      end loop;
      Tmp := To_Bytes(A(0));
      Ada.Text_IO.Put("L_1");
      for i in Tmp'Range loop
          Ada.Text_IO.Put(Tmp(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;
   end Setup;

   -----------------------------------------------------------------

   function Stretch_Then_Shift(Value        : Bytes;
                               Amount       : Natural) return Block is
      K : Block := To_Block(Value);
      L : Bytes := Value;
      R : Bytes := Zero_Bytes;
   begin
      --stretch 
      L := To_Bytes(Shift_Left(K, Amount));    
  
      --110
      K := K xor Shift_Left(K, 8); -- specified in docu      
      R := To_Bytes(Shift_Right(K, Bytes_Per_Block*8 - Amount));      

      --Shift
      L := To_Bytes(To_Block(L) xor To_Block(R)); 
      
      return To_Block(L);
   end Stretch_Then_Shift;

   -----------------------------------------------------------------

    function Padding_One_Zero (Value      : Bytes;
                               Bytes_Read : Natural ) return Block is
      Result : Bytes := Zero_Bytes;
      One_Zero : constant Byte := 2#1000_0000#;
   begin
      if Bytes_Read < Bytes_Per_Block then
         Result(0 .. Bytes_Read - 1) := Value(0 .. Bytes_Read - 1);
         Result(Bytes_Read) := One_Zero;
      elsif Bytes_Read = Bytes_Per_Block then
         Result := Value;
      end if;
      return To_Block(Result);
   end Padding_One_Zero;

   -----------------------------------------------------------------

   -- This function converts the byte-length of the last Ciphertext block
   -- in the binary representation and returns a Block_Type.
   function Convert_Length_To_Block(N: in Natural) return Block is
      B: Bytes := Zero_Bytes;
      W: constant Word := Word(N);
      B_Word: constant Byte_Word := To_Byte_Word(W); -- subtype Byte_Word is Bytes (0 .. 3);
   begin
      B(B'Last-(B_Word'Length-1)..B'Last) := B_Word;
      return To_Block_Type(B);
   end Convert_Length_To_Block;

   -----------------------------------------------------------------

   -- This procedure seperates the last Ciphertext block and the Tag (out of
   -- one or two blocks).
   procedure Extract(This       : in     AE_OCB;
                     A          : in     Bytes;
                     B          : in     Bytes := Zero_Bytes;
                     Bytes_Read : in     Natural;  -- Bytes_Read never zero when calling this procedure!
                     Bitlen     : in out Block;
                     Bytelen    : out    Natural;
                     Last_Block : in out Bytes;    -- initialized as Zero_Block
                     Tag        : in out Bytes;    -- initialited as Zero_Block
                     Two_Blocks : in     Boolean;
                     Dec        : out    Boolean) is
      Overlap: constant Integer := Bytes_Read - This.Taglen;
   begin
      Dec := False;
      if Two_Blocks then

         if Store_Internally then
            -- both blocks (A and B) must be append to Masked_Plaintext
            Masked_Plaintext.Append(A);
            Masked_Plaintext.Append(B);
         end if;
         -- A is Ciphertext and within B is the Tag, with T <= BPB
         if (Bytes_Read - This.Taglen) = 0 then
            Last_Block := A;
            Tag(Tag'First..This.Taglen-1) := B(B'First..This.Taglen-1);
            Bytelen := Bytes_Per_Block;
            Bitlen := Convert_Length_To_Block(8 * Bytelen);

         -- A contains a part of the Tag
         elsif (Bytes_Read - This.Taglen) < 0 then
            Last_Block(Last_Block'First..Bytes_Per_Block-abs(Overlap)-1) := A(A'First..Bytes_Per_Block-abs(Overlap)-1);
            Tag(Tag'First..abs(Overlap)-1) := A(Bytes_Per_Block-abs(Overlap)..A'Last);
            Tag(abs(Overlap)..abs(Overlap)+Bytes_Read-1) := B(B'First..B'First+Bytes_Read-1);
            Bytelen := (Bytes_Per_Block-abs(Overlap));
            Bitlen := Convert_Length_To_Block(8 * Bytelen);

         -- A is an entire Ciphertext block. B contains the last
         -- Ciphertext bytes and the Tag, so A must be decrypt.
         elsif (Bytes_Read - This.Taglen) > 0 then
            Dec := True;
            Last_Block(Last_Block'First..Overlap-1) := B(B'First..Overlap-1);
            Tag(Tag'First..This.Taglen-1) := B(Overlap..Bytes_Read-1);
            Bytelen := Overlap;
            Bitlen := Convert_Length_To_Block(8 * Bytelen);
         end if;

      else
         if Store_Internally then
            -- Only block A must be append to Masked_Plaintext
            Masked_Plaintext.Append(A);
         end if;

         if Overlap < 0 then
            raise Invalid_Ciphertext_Error;
         elsif Overlap = 0 then -- no Ciphertext was written (|M| = 0)
            Tag(Tag'First..This.Taglen-1) := A(A'First..A'First+This.Taglen-1);
            Bytelen := 0;
            Bitlen := Convert_Length_To_Block(Bytelen);
         else
            Last_Block(Last_Block'First..Last_Block'First+Overlap-1) := A(A'First..A'First+Overlap-1);
            Tag(Tag'First..Tag'First+This.Taglen-1) := A(Overlap..Bytes_Read-1);
            Bytelen := Overlap;
            Bitlen := Convert_Length_To_Block(8 * Bytelen);
         end if;

      end if;
   end Extract;

   -----------------------------------------------------------------

   -- This function counts the number of trailing 0-bits in the binary
   -- representation of "Value" (current number of en- or de-crypted
   -- blocks, started at 1.
   function Number_Of_Trailing_Zeros(Value : in Positive) return Natural is
      C: Natural := 0;
      X: Positive := Value;
   begin
      if (Word(Value) and 16#01#) /= 0 then
         return C;
      else
         C := C + 1;
         for I in 1..Positive'Size loop
            X := Shift_Right(X,1);
            if (Word(X) and 16#01#) /= 0 then
               return C;
            else
               C := C + 1;
            end if;
         end loop;
      end if;
      return C;
   end Number_Of_Trailing_Zeros;

   -----------------------------------------------------------------

   -- This procedure is called every time a block must be encrypted.
   -- Also the Offset, Checksum and the number of encrypted blocks
   -- will be updated. The encrypted block will be written.
   procedure Aux_Enc (This     :  in     AE_OCB;
                      Offset   :  in out Block;
                      Checksum :  in out Block;
                      Count    :  in out Positive;
                      Write    :  in     Callback_Writer;
                      Input    :  in     Block;
                      Output   :  in out Block) is
      Tmp : Bytes(0 .. Bytes_Per_Block - 1);
   begin
      --113 Offset = Offset XOR L
      Offset := Offset xor This.L_Array(Number_Of_Trailing_Zeros(Count) - 1);
      Tmp := To_Bytes(Offset);
      Ada.Text_IO.Put("Offset");
      for i in Tmp'Range loop
          Ada.Text_IO.Put(Tmp(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;      

      --114
      BC.Encrypt(Input xor Offset, Output);
      Output := Output xor Offset;
      Write(To_Bytes(Output));
      --115
      Checksum := Checksum xor Input;
      Tmp := To_Bytes(Checksum);
      Ada.Text_IO.Put("Checksum");
      for i in Tmp'Range loop
          Ada.Text_IO.Put(Tmp(i)'Img);
      end loop;
      Ada.Text_IO.New_Line; 
      Count := Count + 1;
   end Aux_Enc;

   -----------------------------------------------------------------

   -- This procedure is called every time a block must be decrypted.
   -- Also the Offset, Checksum and the number of decrypted blocks
   -- will be updated. The decrypted block will be first masked
   -- and then written.
   procedure Aux_Dec (This     :  in     AE_OCB;
                      Offset   :  in out Block;
                      Checksum :  in out Block;
                      Count    :  in out Positive;
                      Input    :  in     Block;
                      Output   :  in out Block) is
   begin
      --313 
      Offset := Offset xor This.L_Array(Number_Of_Trailing_Zeros(Count) - 1);    

      --314
      BC.Decrypt(Input xor Offset, Output);
      Output := Output xor Offset;
     
      --315
      Checksum := Checksum xor Output;
      Count := Count + 1;
   end Aux_Dec;

   -----------------------------------------------------------------

   -- This procedure decrypt and write each Ciphertext block. It won't
   -- be called, if the calculated Tag isn't the same as the specified.
   procedure Write_Decrypted_Plaintext(This                  : in AE_OCB;
                                       Read_Ciphertext_Again : in Callback_Reader;
                                       Write_Plaintext       : in Callback_Writer;
                                       Dec_Bool              : in Boolean;
                                       Last_P_Block          : in Bytes;
                                       Last_B_Bytelen        : in Natural) is

      Bytes_Read: Natural;
      Blockcount: Positive := 1;
      Offset: Block := This.Offset;
      Checksum: Block := Zero_Block;
      Plaintext: Block;

      First_Block: Bytes := Zero_Bytes;
      Second_Block: Bytes := Zero_Bytes;
      Third_Block: Bytes := Zero_Bytes;
   begin
      Read_Ciphertext_Again(First_Block, Bytes_Read);
      if Bytes_Read = 0 then
         raise Invalid_Ciphertext_Error;
      elsif
         Bytes_Read < Bytes_Per_Block then
         null;
      else
         Read_Ciphertext_Again(Second_Block, Bytes_Read);

         -- If Bytes_Read = 0, only Last_P_Block must be written
         -- If (Bytes_Per_Block > Bytes_Read > 0) and Dec_Bool = True then
         -- First_Block will be decrypt, else only Last_P_Block will be written
         if Bytes_Read = Bytes_Per_Block then
            loop
               Read_Ciphertext_Again(Third_Block, Bytes_Read);

               if Bytes_Read = Bytes_Per_Block then
                  Aux_Dec(This     => This,
                          Offset   => Offset,
                          Checksum => Checksum,
                          Count    => Blockcount,
                          Input    => To_Block_Type(First_Block),
                          Output   => Plaintext);
                  Write_Plaintext(To_Bytes(Plaintext));
                  First_Block := Second_Block;
                  Second_Block := Third_Block;
               elsif Bytes_Read = 0 then
                  Bytes_Read := Bytes_Per_Block;
                  exit;
               else
                  Aux_Dec(This     => This,
                          Offset   => Offset,
                          Checksum => Checksum,
                          Count    => Blockcount,
                          Input    => To_Block_Type(First_Block),
                          Output   => Plaintext);
                  Write_Plaintext(To_Bytes(Plaintext));

                  First_Block := Second_Block;
                  Second_Block := Third_Block;
                  exit;
               end if;
            end loop;
         end if;
      end if;

      if Dec_Bool then
         Aux_Dec(This     => This,
                 Offset   => Offset,
                 Checksum => Checksum,
                 Count    => Blockcount,
                 Input    => To_Block_Type(First_Block),
                 Output   => Plaintext);
         Write_Plaintext(To_Bytes(Plaintext));
      end if;

      -- write last Plaintext bytes
      if Last_B_Bytelen > 0 then
         Write_Plaintext(Last_P_Block(Last_P_Block'First..Last_B_Bytelen-1));
      end if;
   end Write_Decrypted_Plaintext;

   -----------------------------------------------------------------
   ----
   ---- overriding functions and procedures
   ----
   -----------------------------------------------------------------

   procedure Init_Encrypt(This   : out    AE_OCB;
                          Key    : in     Key_Type;
                          Nonce  : in out N.Nonce'Class) is
   begin
      This.Nonce_Value := Nonce.Update;
      BC.Prepare_Key(Key);
      Setup(Key, This.L_Array);
      This.Taglen := Bytes_Per_Block;
   end Init_Encrypt;

   -----------------------------------------------------------------

   procedure Init_Decrypt(This        : out AE_OCB;
                          Key         : in  Key_Type;
                          Nonce_Value : in  Block) is
   begin
      BC.Prepare_Key(Key);
      Setup(Key, This.L_Array);
      This.Nonce_Value := Nonce_Value;
      This.Taglen := Bytes_Per_Block;
      BC.Encrypt(This.Nonce_Value xor This.L_Array(0), This.Offset);
   end Init_Decrypt;

   -----------------------------------------------------------------

   procedure Encrypt(This             : in out AE_OCB;
                     Read_Plaintext   : in     Callback_Reader;
                     Write_Ciphertext : in     Callback_Writer) is

      Bytes_Read: Natural;
      Ciphertext : Block;
      Offset: Block := This.Offset;
      Blockcount: Positive := 1;
      Checksum: Block := Zero_Block;
      Nonce: Bytes := Zero_Bytes;
      Pad : Block;

      Last_C_Block: Bytes := Zero_Bytes;     -- last Ciphertext block in bytes
      Last_P_Block: Bytes(Zero_Bytes'Range); -- last Plaintext block in bytes

      Prev_Block: Bytes := Zero_Bytes;
      Curr_Block: Bytes := Zero_Bytes;

      Tmp1 :Bytes := Zero_Bytes;
      Tmp : Block := To_Block(Zero_Bytes xor 2#0000_1111#);--8+4+2+1=15
   begin

      Ada.Text_IO.Put_Line("Test for Double_S");
      Tmp1 :=To_Bytes(Double_S(Tmp)); 
      for i in Tmp1'Range loop
         Ada.Text_IO.Put(Tmp1(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;
      Ada.Text_IO.New_Line;

      --read the first block of plaintext
      Read_Plaintext(Prev_Block, Bytes_Read);
      --check if the block is the last block
      if Bytes_Read < Bytes_Per_Block then
         Last_P_Block(Prev_Block'First..Prev_Block'First+Prev_Block'Length-1) := Prev_Block;
      else
         loop
            Read_Plaintext(Curr_Block, Bytes_Read);

            if Bytes_Read = Bytes_Per_Block then
               Aux_Enc(This       => This,
                       Offset     => Offset,
                       Checksum   => Checksum,
                       Write      => Write_Ciphertext,
                       Count      => Blockcount,
                       Input      => To_Block_Type(Prev_Block),
                       Output     => Ciphertext);
               Prev_Block := Curr_Block;

            elsif Bytes_Read = 0 then
               Last_P_Block := Prev_Block;
               -- Assigning is important for later use:
               Bytes_Read := Bytes_Per_Block;
               exit;
            else
               Aux_Enc(This       => This,
                       Offset     => Offset,
                       Checksum   => Checksum,
                       Write      => Write_Ciphertext,
                       Count      => Blockcount,
                       Input      => To_Block_Type(Prev_Block),
                       Output     => Ciphertext);
               Last_P_Block := Curr_Block;
               exit;
            end if;

         end loop;
      end if;
      
      if Bytes_Read > 0 then
         --117
            Offset := Offset xor L_Star;
            Tmp1 :=To_Bytes(Offset);
            Ada.Text_IO.Put("Offset_*"); 
            for i in Tmp1'Range loop
                Ada.Text_IO.Put(Tmp1(i)'Img);
            end loop;
            Ada.Text_IO.New_Line;
         --118
            BC.Encrypt(Offset, Pad);
         declare
            C: Bytes := To_Bytes(Pad);
         begin
         --119
            Last_C_Block(0..Bytes_Read-1) := Last_P_Block(0..Bytes_Read-1) xor C(C'First..C'First+Bytes_Read-1);
         end;
         --120 
         Checksum := Checksum xor Padding_One_Zero(Last_P_Block, Bytes_Read);
         Tmp1 := To_Bytes(Checksum);

         Ada.Text_IO.Put("Checksum_*");
         for i in Tmp1'Range loop
             Ada.Text_IO.Put(Tmp1(i)'Img);
         end loop;
         Ada.Text_IO.New_Line; 
      end if;
      --121
      Offset := Offset xor L_Dollar;
      
      --122 calculate the Tag
      BC.Encrypt(Checksum xor Offset, Ciphertext);
      Tmp1 := To_Bytes(Ciphertext);
      Ada.Text_IO.Put("Tag: ");
      for i in Tmp1'Range loop
         Ada.Text_IO.Put(Tmp1(i)'Img);
      end loop;
      Ada.Text_IO.New_Line;

      
      -- concatenate the last block and Tag (if necessary)
      declare
         C: constant Bytes := To_Bytes(Ciphertext);
      begin
         if Bytes_Read < Bytes_Per_Block then
            declare
               -- |B| = |last message block| + |desired Tag|
               B: Bytes(0..(Bytes_Read+This.Taglen-1));
            begin
               -- concatenate last Ciphertext bytes with the Tag
               B(B'First..Bytes_Read-1) := Last_C_Block(Last_C_Block'First..Bytes_Read-1);
               B(Bytes_Read..B'Last) := C(C'First..C'First+This.Taglen-1);
               if B'Length > Bytes_Per_Block then
                  Write_Ciphertext(B(B'First..Bytes_Per_Block-1));
                  declare
                     -- This step is only for normalizing the index (starting at 0)
                     Temp: constant Bytes(0..(B'Length-Bytes_Per_Block)-1) := B(Bytes_Per_Block..B'Last);
                  begin
                     Write_Ciphertext(Temp);
                  end;
               else
                  Write_Ciphertext(B(B'First..B'Last));
               end if;
            end;
         else
           -- write the last Ciphertext block an the Tag
            Write_Ciphertext(Last_C_Block);
            Write_Ciphertext(C(C'First..This.Taglen-1));
         end if;
      end;

   end Encrypt;

   -----------------------------------------------------------------

   function Aux_Decrypt(This                   : in AE_OCB;
                        Read_Ciphertext        : in Callback_Reader;
                        Read_Ciphertext_Again  : in Callback_Reader;
                        Write_Plaintext        : in Callback_Writer)
                        return Boolean is

      Bytes_Read: Natural;
      Blockcount: Positive := 1;
      Offset: Block := This.Offset;
      Checksum: Block := Zero_Block;
      Plaintext: Block;
      Tag, Tmp: Bytes := Zero_Bytes;
      T, Pad : Block;
      Dec_Bool: Boolean;
      Verification_Bool: Boolean := False;

      Last_P_Block: Bytes := Zero_Bytes;  -- last Plaintext block in bytes
      Last_C_Block: Bytes := Zero_Bytes;  -- last Ciphertext block in bytes
      Last_B_Bitlen: Block := Zero_Block; -- bit-length of the last block represented as Block
      Last_B_Bytelen: Natural;            -- byte-length of the last block

      First_Block: Bytes := Zero_Bytes;
      Second_Block: Bytes := Zero_Bytes;
      Third_Block: Bytes := Zero_Bytes;
   begin
      Read_Ciphertext(First_Block, Bytes_Read);

      if Bytes_Read = 0 then
         -- Tag must be at least 1 byte
         raise Invalid_Ciphertext_Error;
      elsif Bytes_Read < Bytes_Per_Block then
         Extract(This       => This,
                 A          => First_Block,
                 Bytes_Read => Bytes_Read,
                 Bitlen     => Last_B_Bitlen,
                 Bytelen    => Last_B_Bytelen,
                 Last_Block => Last_C_Block,
                 Tag        => Tag,
                 Two_Blocks => False,
                 Dec        => Dec_Bool);
      else
         Read_Ciphertext(Second_Block, Bytes_Read);
         
         if Bytes_Read < Bytes_Per_Block then
            if Bytes_Read = 0 then
               -- First_Block was the last block and filled up
               Bytes_Read := Bytes_Per_Block;
               Extract(This       => This,
                       A          => First_Block,
                       Bytes_Read => Bytes_Read,
                       Bitlen     => Last_B_Bitlen,
                       Bytelen    => Last_B_Bytelen,
                       Last_Block => Last_C_Block,
                       Tag        => Tag,
                       Two_Blocks => False,
                       Dec        => Dec_Bool);
            else
               Extract(This       => This,
                       A          => First_Block,
                       B          => Second_Block,
                       Bytes_Read => Bytes_Read,
                       Bitlen     => Last_B_Bitlen,
                       Bytelen    => Last_B_Bytelen,
                       Last_Block => Last_C_Block,
                       Tag        => Tag,
                       Two_Blocks => True,
                       Dec        => Dec_Bool);
            end if;
         else
            loop
               Read_Ciphertext(Third_Block, Bytes_Read);

               if Bytes_Read = Bytes_Per_Block then
                  Aux_Dec(This     => This,
                          Offset   => Offset,
                          Checksum => Checksum,
                          Count    => Blockcount,
                          Input    => To_Block_Type(First_Block),
                          Output   => Plaintext);

                  if Store_Internally then
                     Masked_Plaintext.Append(First_Block);
                  end if;

                  First_Block := Second_Block;
                  Second_Block := Third_Block;
               elsif Bytes_Read = 0 then
                  -- Second_Block was a full block
                  Bytes_Read := Bytes_Per_Block;
                  Extract(This       => This,
                          A          => First_Block,
                          B          => Second_Block,
                          Bytes_Read => Bytes_Read,
                          Bitlen     => Last_B_Bitlen,
                          Bytelen    => Last_B_Bytelen,
                          Last_Block => Last_C_Block,
                          Tag        => Tag,
                          Two_Blocks => True,
                          Dec        => Dec_Bool);
                  exit;
               else
                  -- decrypt First_Block
                  Aux_Dec(This     => This,
                          Offset   => Offset,
                          Checksum => Checksum,
                          Count    => Blockcount,
                          Input    => To_Block_Type(First_Block),
                          Output   => Plaintext);

                  if Store_Internally then
                     Masked_Plaintext.Append(First_Block);
                  end if;

                  -- Assigning is important because, if Dec_Bool = True,
                  -- First_Block will be used later for decryption.
                  First_Block := Second_Block;
                  Second_Block := Third_Block;

                  Extract(This       => This,
                          A          => First_Block,
                          B          => Second_Block,
                          Bytes_Read => Bytes_Read,
                          Bitlen     => Last_B_Bitlen,
                          Bytelen    => Last_B_Bytelen,
                          Last_Block => Last_C_Block,
                          Tag        => Tag,
                          Two_Blocks => True,
                          Dec        => Dec_Bool);
                  exit;
               end if;
            end loop;
         end if;
      end if;

      -- If B containts last Ciphertext bytes
      -- and the Tag, A must be decrypt.
      if Dec_Bool then
         Aux_Dec(This     => This,
                 Offset   => Offset,
                 Checksum => Checksum,
                 Count    => Blockcount,
                 Input    => To_Block_Type(First_Block),
                 Output   => Plaintext);
      end if;

      --317
      Offset := Offset xor L_Star;
       
      --318
      BC.Encrypt(Offset, Pad);
      declare
         C: Bytes := To_Bytes(Pad);
      begin
      --319
         Last_P_Block(0..Bytes_Read-1) := Last_C_Block(0..Bytes_Read-1) xor C(0 .. Bytes_Read-1);
      end;
      --320 
      Checksum := Checksum xor Padding_One_Zero(Last_P_Block, Bytes_Read);
      
      --321
      Offset := Offset xor L_Dollar;
      
      --322 Final -> Tag
      BC.Encrypt(Checksum xor Offset, T);      
     
      declare
         Calculated_Tag: constant Bytes := To_Bytes(T);
      begin
         if Tag(Tag'First..This.Taglen-1) = Calculated_Tag(Calculated_Tag'First..This.Taglen-1) then
            Verification_Bool := True;
            Write_Decrypted_Plaintext(This, Read_Ciphertext_Again, Write_Plaintext, Dec_Bool, Last_P_Block, Last_B_Bytelen);
         end if;
      end;

      return Verification_Bool;

   end Aux_Decrypt;

   -----------------------------------------------------------------

   function Decrypt_And_Verify(This                   : in out AE_OCB;
                               Read_Ciphertext        : in     Callback_Reader;
                               Read_Ciphertext_Again  : in     Callback_Reader := null;
                               Write_Plaintext        : in     Callback_Writer)
                               return Boolean is

      RCA: constant Callback_Reader := Read_Masked_Plaintext'Access;
   begin
      if Read_Ciphertext_Again = null then

         Store_Internally := True;

         return Aux_Decrypt(This                   => This,
                            Read_Ciphertext        => Read_Ciphertext,
                            Read_Ciphertext_Again  => RCA,
                            Write_Plaintext        => Write_Plaintext);
      else
         return Aux_Decrypt(This                   => This,
                            Read_Ciphertext        => Read_Ciphertext,
                            Read_Ciphertext_Again  => Read_Ciphertext_Again,
                            Write_Plaintext        => Write_Plaintext);
      end if;

   end Decrypt_And_Verify;

   -----------------------------------------------------------------
   ----
   ---- additional functions and procedures
   ----
   -----------------------------------------------------------------

   procedure Init_Encrypt(This                : out    AE_OCB;
                          Key                 : in     Key_Type;
                          N_Init              : in out N.Nonce'Class;
                          Bytes_Of_N_Read     : in     Positive;
                          Taglen              : in     Positive) is
         Top, Bottom : Bytes := Zero_Bytes;
         Tmp_Top : Bytes(0..(Bytes_Per_Block - 1)) := (others => 2#1111_1111#);
         Tmp_Bottom : Bytes := Zero_Bytes;
         Ktop : Block := Zero_Block;
         Tmp : Bytes(0..(Bytes_Per_Block - 1));
   begin  
         --102
         if Bytes_Of_N_Read > 16 then
            raise Noncelength_Not_Supported;
         else
            BC.Prepare_Key(Key);
            Setup(Key, This.L_Array);
            This.Nonce_Value := N_Init.Update;
            This.Taglen := Taglen;
            --Generate_L(This.L_Array);
            
            --106: Nonce_Init = 0^(127- |N|) 1 N
            Nonce_Init(Bytes_Per_Block - Bytes_Of_N_Read .. Bytes_Per_Block - 1) := To_Bytes(This.Nonce_Value)(0.. Bytes_Of_N_Read - 1) ;
            Nonce_Init(Bytes_Per_Block - Bytes_Of_N_Read - 1) := 2#0000_0001# ;
            
            Ada.Text_IO.Put("Nonce");
            for i in Nonce_Init'Range loop
                Ada.Text_IO.Put(Nonce_Init(i)'Img);
            end loop;
            Ada.Text_IO.New_Line; 
            

            --107: Top = Nonce AND (1^122 0^6)
            Tmp_Top(Tmp_Top'Last) := 2#1100_0000#;
            Top := Nonce_Init and Tmp_Top;

            --108: Bottom = Nonce AND (0^122 1^6)
            Tmp_Bottom(Tmp_Bottom'Last) := 2#0011_1111#;
            Bottom := Nonce_Init and Tmp_Bottom;
            Ada.Text_IO.Put("Bottom");
            for i in Bottom'Range loop
                Ada.Text_IO.Put(Bottom(i)'Img);
            end loop;
            Ada.Text_IO.New_Line;
          

            --109: Ktop = Ek(Top)
            BC.Encrypt(To_Block(Top), Ktop);
            Tmp := To_Bytes(Ktop);
            Ada.Text_IO.Put("Ktop");
            for i in Tmp'Range loop
                Ada.Text_IO.Put(Tmp(i)'Img);
            end loop;
            Ada.Text_IO.New_Line;

            --110-111: Offset = (Stretch<<Bottom)[1..128]
            This.Offset := Stretch_Then_Shift(To_Bytes(Ktop), Integer(Bottom(Bottom'Last)));
            Tmp := To_Bytes(This.Offset);
            Ada.Text_IO.Put("Initial Offset");
            for i in Tmp'Range loop
                Ada.Text_IO.Put(Tmp(i)'Img);
            end loop;
            Ada.Text_IO.New_Line;  
         end if;
   end Init_Encrypt;

   -----------------------------------------------------------------

   procedure Init_Decrypt(This                : out    AE_OCB;
                          Key                 : in     Key_Type;
                          N_Init              : in     Block;
                          Bytes_Of_N_Read     : in     Positive;
                          Taglen              : in     Positive) is
         Top, Bottom : Bytes := Zero_Bytes;
         Tmp_Top : Bytes(0..(Bytes_Per_Block - 1)) := (others => 2#1111_1111#);
         Tmp_Bottom : Bytes := Zero_Bytes;
         Ktop : Block := Zero_Block;    
   begin
      --302
      if Bytes_Of_N_Read > 16 then
         raise Noncelength_Not_Supported;
      else
         BC.Prepare_Key(Key);
         Setup(Key, This.L_Array);
         This.Nonce_Value := N_Init;
         This.Taglen := Taglen;
     
      --306
         Nonce_Init(Bytes_Per_Block - Bytes_Of_N_Read .. Bytes_Per_Block - 1) := To_Bytes(This.Nonce_Value)(0.. Bytes_Of_N_Read - 1) ;
         Nonce_Init(Bytes_Per_Block - Bytes_Of_N_Read - 1) := 2#0000_0001# ;
            
      --307
         Tmp_Top(Tmp_Top'Last) := 2#1100_0000#;
         Top := Nonce_Init and Tmp_Top;

      --308
         Tmp_Bottom(Tmp_Bottom'Last) := 2#0011_1111#;
         Bottom := Nonce_Init and Tmp_Bottom;
        
      --309
         BC.Encrypt(To_Block(Top), Ktop);

      --310-311
         This.Offset := Stretch_Then_Shift(To_Bytes(Ktop), Integer(Bottom(Bottom'Last)));         
      end if;
   end Init_Decrypt;

   -----------------------------------------------------------------

end Crypto.Symmetric.AE_OCB3;