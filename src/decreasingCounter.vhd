library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--------------------------------------------------------------------------------
-- Entity that performs the deacreasing counter.
-------------------------------------------------------------------------------
entity decreasingCounter is
   generic(
   	-- Reset value of counter register.
   	C_START_VALUE : integer := 16#7FFFFFFF#;
   	-- Maximum number of counting cycles.
   	C_MAX_CYCLES : integer := 5;
   	-- Bitwidth of TDATA signal of AXI STREAM port.
   	C_AXIS_TDATA_WIDTH : integer := 32;
   	-- Bitwidth of TUSER signal of AXI STREAM port.
   	C_AXIS_TUSER_WIDTH : integer := 5
   );
   port(
      M_AXIS_ACLK : in std_logic;
      M_AXIS_ARESETN : in std_logic;
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA : out std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
      M_AXIS_TLAST : out std_logic;
      M_AXIS_TUSER : out std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0); 
      M_AXIS_TREADY : in std_logic
   );
end entity decreasingCounter;

architecture RTL of decreasingCounter is
   -- Bitwidth of nibble (hexadecimal character)
   constant NIBBLE_WIDTH : integer := 4;
    
   -----------------------------------------------------------------------------
   -- Function to get TUSER(0) from counter
   -----------------------------------------------------------------------------
   function F_TUSER0(arg_counter : unsigned) return std_logic is
      constant TUSER0_4LSB_MATCH : unsigned(NIBBLE_WIDTH-1 downto 0) := x"F";
      variable ret : std_logic;
   begin
      if arg_counter(NIBBLE_WIDTH-1 downto 0) = TUSER0_4LSB_MATCH then
         ret := '1';
      else
         ret := '0';
      end if;
        
      return ret;
   end function F_TUSER0;
   
   -----------------------------------------------------------------------------
   -- Function to get TUSER(1) from counter
   -----------------------------------------------------------------------------
   function F_TUSER1(arg_counter : unsigned) return std_logic is
      constant MODULO_DIVISOR : integer := 32;
      constant MODULO_WIDTH : integer := integer(log2(real(MODULO_DIVISOR)));
      
      constant SUM_MATCH : integer := 5;
      constant NIBBLE_COUNT : integer := arg_counter'length/NIBBLE_WIDTH;
      constant SUM_WIDTH : integer := NIBBLE_WIDTH + integer(log2(real(NIBBLE_COUNT)));
      
      variable ret : std_logic;
      variable sum_v : unsigned(SUM_WIDTH-1 downto 0);
   begin
      sum_v := (others => '0');
      for i in 0 to NIBBLE_COUNT-1 loop
        sum_v := sum_v + arg_counter(i*NIBBLE_WIDTH+3 downto i*NIBBLE_WIDTH);
      end loop;
      
      -- 5lsb is equal to module 32.
      if to_integer(sum_v(MODULO_WIDTH-1 downto 0)) = SUM_MATCH then
         ret := '1';
      else
         ret := '0';
      end if;
      
      return ret;
   end function F_TUSER1;
   
   -----------------------------------------------------------------------------
   -- Function to get TUSER(2) from counter
   -----------------------------------------------------------------------------
   function F_TUSER2(arg_counter : unsigned) return std_logic is
      constant QUOTIENT_MATCH : integer := 7;
      constant DIV_NUMERATOR : integer := 8;
      constant DIV_NUM_LOG2 : integer := integer(ceil(log2(real(DIV_NUMERATOR))));
      constant DIV_DENOMINATOR : natural := 3;
      constant PRODUCT_WIDTH : integer := arg_counter'length + DIV_NUM_LOG2;
      constant QUOTIENT_WIDTH : integer := PRODUCT_WIDTH - DIV_NUM_LOG2;
       
      variable ret : std_logic;
      variable product_v : unsigned(PRODUCT_WIDTH-1 downto 0);
      variable quotient_v : unsigned(QUOTIENT_WIDTH -1 downto 0);
   begin
      -- compute counter/(8/3) as (counter*3)/8, which is obtained by
      -- removing the 3 lsb of the product counter*3.
      product_v := to_unsigned(to_integer(arg_counter)*DIV_DENOMINATOR, PRODUCT_WIDTH);
      quotient_v := product_v(product_v'length-1 downto DIV_NUM_LOG2);
      
      -- compute product_v/8 as 
      if to_integer(quotient_v) = QUOTIENT_MATCH then
         ret := '1';
      else
         ret := '0';
      end if;
      
      return ret;
   end function F_TUSER2;

   -----------------------------------------------------------------------------
   -- Function to get TUSER(3) from counter
   -----------------------------------------------------------------------------
   function F_TUSER3(arg_counter : unsigned) return std_logic is
      constant REMAINDER_MATCH : integer := 16#A#;
      constant REMAINDER_DIV : integer := 128;
      constant REMAINDER_WIDTH : integer := integer(log2(real(REMAINDER_DIV)));
      variable ret : std_logic;
   begin
      if to_integer(arg_counter(REMAINDER_WIDTH-1 downto 0)) = REMAINDER_MATCH then
         ret := '1';
      else
         ret := '0';
      end if;    
      
      return ret;
   end function F_TUSER3;
   
   -----------------------------------------------------------------------------
   -- Function to get TUSER(4) from TUSER(3 downto 0)
   -----------------------------------------------------------------------------
   function F_TUSER4(arg_tuser : std_logic_vector) return std_logic is
      variable ret : std_logic;
   begin
      
      ret := '1';
      for i in arg_tuser'range loop
         ret := ret and arg_tuser(i);
      end loop;
      
      return ret;
   end function F_TUSER4;
   
   -----------------------------------------------------------------------------
   -- Function to get TUSER port from counter
   -----------------------------------------------------------------------------
   function F_TUSER(arg_counter: integer range 0 to C_START_VALUE)
   return std_logic_vector is
      variable ret : std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
      variable counter_v : unsigned(C_AXIS_TDATA_WIDTH-1 downto 0);
   begin
      counter_v := to_unsigned(arg_counter, C_AXIS_TDATA_WIDTH);

      ret(0) := F_TUSER0(counter_v);
      ret(1) := F_TUSER1(counter_v);
      ret(2) := F_TUSER2(counter_v);
      ret(3) := F_TUSER3(counter_v);
      ret(4) := ret(0) and ret(1) and ret(2) and ret(3);
      
      return ret;
   end function F_TUSER;
   
   -----------------------------------------------------------------------------
   -- REGISTERS
   -----------------------------------------------------------------------------
   -- Decreasing counter
   signal counter : integer range 0 to C_START_VALUE;
   -- Counter of remaining counting cycles.
   signal cycles : integer range 0 to C_MAX_CYCLES-1;
   -- Register with the status shared on M_AXIS_TUSER
   signal axis_tuser : std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
   -- This signal asserted is valid and coherent with counter value.
   signal tuser_valid : std_logic;
   -- This signal assert that all the counting cycles have finished
   signal fineshed : std_logic;   
   -- This signal assert that counter is equal to zero.
   signal is_zero : std_logic; 
   -- This signal assert the current cycle is the last. It remains equal to '1'
   -- when the last cycle ends.
   signal last_cycle : std_logic;

   -----------------------------------------------------------------------------
   -- NETS
   -----------------------------------------------------------------------------      
   -- This signal signs an AXIS transaction in current clock edge.
   signal counter_update : std_logic;
   -- AXI Stream tvalid signal
   signal axis_tvalid : std_logic;
begin
   
   axis_tvalid <= tuser_valid and not fineshed;
   counter_update <= axis_tvalid and M_AXIS_TREADY;
   
   M_AXIS_TDATA <= std_logic_vector(to_unsigned(counter, C_AXIS_TDATA_WIDTH));
   M_AXIS_TLAST <= last_cycle and is_zero;
   M_AXIS_TVALID <= axis_tvalid;
   M_AXIS_TUSER <= axis_tuser;
   
   -----------------------------------------------------------------------------
   -- Process to update the decreasing counter when current value
   -- is sent to AXI stream slave.
   -----------------------------------------------------------------------------
   StreamCounter : process (M_AXIS_ACLK) is
   begin
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then
            counter <= C_START_VALUE;
         elsif counter_update = '1' then
            if is_zero = '1' then
               if last_cycle = '0' then
                  counter <= C_START_VALUE;
               else
                  counter <= 0;
               end if;
            else
               counter <= counter - 1;
            end if;
         end if;
        
      end if;
   end process StreamCounter;
   
   -----------------------------------------------------------------------------
   -- Process to synchronously update AXI Stream TUSER port.
   --
   -- The combined propagation delay of updating the counter and tuser
   -- could lead to time problems. Thus a pipeline approach is used
   -- such that tuser is updated at the next clock edge.
   -----------------------------------------------------------------------------
   AXISTUSERUpdate : process (M_AXIS_ACLK) is
   begin
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then
            axis_tuser <= (others => '0');
            tuser_valid <= '0';
         else
                        
            axis_tuser <= F_TUSER(counter);

            -- tuser is invalid in the first clock cycle after counter update.
            tuser_valid <= not counter_update;
         end if;
      end if;
   end process AXISTUSERUpdate;
     
   -----------------------------------------------------------------------------     
   -- Process to track the number of remaining count-cycles.
   -----------------------------------------------------------------------------
   CyclesCounter : process (M_AXIS_ACLK) is
   begin
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then 
            cycles <= C_MAX_CYCLES - 1;
         elsif counter_update = '1' and is_zero = '1'and last_cycle = '0' then 
            cycles <= cycles - 1;
         end if;
      end if;
   end process CyclesCounter;
      
   -----------------------------------------------------------------------------      
   -- Process to assert when the counter is equal to zero.
   -----------------------------------------------------------------------------
   ZeroTrigger : process (M_AXIS_ACLK) is
   begin      
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then
            is_zero <= '0';
         elsif counter_update = '1' then 
            if counter = 1 then
               is_zero <= '1';
            else
               is_zero <= '0';
            end if;   
         end if;
      end if;
   end process ZeroTrigger;
   
   -----------------------------------------------------------------------------
   -- Process to assert when current cycle is the last.
   -----------------------------------------------------------------------------
   LastCycleTrigger : process (M_AXIS_ACLK) is
   begin
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then
            last_cycle <= '0';      
         elsif counter_update = '1' and is_zero = '1' and cycles = 1 then
            last_cycle <= '1';
         end if;
      end if;
   end process LastCycleTrigger;

   -----------------------------------------------------------------------------   
   -- Process to assert when all the cycles have ended.
   -----------------------------------------------------------------------------
   CompletionTrigger : process (M_AXIS_ACLK) is
   begin
      if rising_edge(M_AXIS_ACLK) then
         if M_AXIS_ARESETN = '0' then
            fineshed <= '0';
         else
            if counter_update = '1' and is_zero = '1' and last_cycle = '1' then
               fineshed <= '1';
            end if;
         end if;
      end if;
   end process CompletionTrigger;

end architecture RTL;
