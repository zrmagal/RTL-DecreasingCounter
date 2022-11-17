library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

--------------------------------------------------------------------------------
-- Test bench entity that test DUT output against the expected value.
--------------------------------------------------------------------------------
entity monitor is
   generic(
      C_AXIS_TDATA_WIDTH : integer := 32;
      C_AXIS_TUSER_WIDTH : integer := 5
   );
   port(
         err_count : out integer;
         tready_in : in std_logic;
      
         S_AXIS_ACLK    : in  std_logic;
         S_AXIS_ARESETN : in std_logic;
         S_AXIS_TVALID  : in std_logic;
         S_AXIS_TDATA   : in std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
         S_AXIS_TLAST   : in std_logic;
         S_AXIS_TUSER   : in std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
         S_AXIS_TREADY  : out  std_logic
   );
end entity monitor;

architecture RTL of monitor is
   -----------------------------------------------------------------------------
   -- Function to test the actual outputs against reference values from file.
   -----------------------------------------------------------------------------  
   impure function F_IS_EQUAL_REF(
      file arg_file : text; 
      tdata : std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
      tuser : std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0)
   ) return std_logic is 
      constant LINE_WIDTH : integer := C_AXIS_TDATA_WIDTH+C_AXIS_TUSER_WIDTH;
      variable ref_counter : std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
      variable ref_tuser : std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
      variable line_v : line;
      variable bits: std_logic_vector((LINE_WIDTH-1) downto 0);
      variable ret : std_logic;
   begin
      if endfile(arg_file) then
         file_close(arg_file);
         file_open(arg_file, "ref.txt", read_mode);
      end if;
         
      readline(arg_file,line_v);
      read(line_v,bits);
      ref_counter := bits(ref_counter'length-1 downto 0);
      ref_tuser := bits(bits'length-1 downto ref_counter'length);
    
      if tdata = ref_counter and tuser = ref_tuser then
         ret := '1';
      else
         ret := '0';
         assert false report
         "EXPECTED " &
         " tdata=" & integer'image(to_integer(unsigned(ref_counter))) & 
         " tuser=" & integer'image(to_integer(unsigned(ref_tuser))) &
         " OBTAINED " &   
         " tdata=" & integer'image(to_integer(unsigned(tdata))) & 
         " tuser=" & integer'image(to_integer(unsigned(tuser)))
         severity error; 
      end if; 
   
        
      return ret;
   end F_IS_EQUAL_REF;
   
   signal counter_update : std_logic;
   signal errors : integer := 0;
   file file_input : text open read_mode is "ref.txt";

begin
   
   S_AXIS_TREADY <= tready_in;
   counter_update <= tready_in and S_AXIS_TVALID;
   err_count <= errors; 
 
   -----------------------------------------------------------------------------
   -- Process to check the output 
   -----------------------------------------------------------------------------     
   OutputChecker : process (S_AXIS_ACLK) is
      variable is_ok : std_logic;
   begin
      if rising_edge(S_AXIS_ACLK) then
         if S_AXIS_ARESETN = '0' then
            file_close(file_input);
            file_open(file_input, "ref.txt", read_mode);
         elsif counter_update = '1' then
            is_ok := F_IS_EQUAL_REF(file_input, S_AXIS_TDATA, S_AXIS_TUSER);
            if is_ok = '0' then
               errors <= errors+ 1;                           
            end if;
         end if;
      end if;
   end process OutputChecker;
end architecture RTL;
