library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- Test bench entity that managers the test by generating the input stimuli.
--------------------------------------------------------------------------------
entity driver is
   generic
   (
       C_RST_ACTIVE_LEVEL : std_logic := '0';
       C_COUNTER_START : integer;
       C_COUNTER_CYCLES : integer
   );
   port(
      clk : in std_logic;
      reset : out std_logic;
      test_end : out std_logic;
      axis_tready : out std_logic;
      axis_tvalid : in std_logic
   );
end entity driver;

architecture RTL of driver is
   
   constant TREADY_INTERVAL_ARRAY_SIZE : integer := 10;
   constant TREADY_INTERVAL_START : integer := 0;
   constant TREADY_INTERVAL_STEP : integer := 2;
   constant RST_INTERVAL_ARRAY_SIZE : integer := 20;
   
   -----------------------------------------------------------------------------
   -- Function to initialize an array of integers
   -----------------------------------------------------------------------------
   type int_array_t is array(integer range <>) of integer;
   
   function F_INIT_INT_ARRAY(
      start: integer;
      step: integer;
      size : integer
   ) return int_array_t is
      variable ret : int_array_t(0 to size-1);
      variable v : integer;
   begin
      v := start;
      for i in ret'range loop
         ret(i) := v;
         v := v + step;
      end loop;
      
      return ret;
   end function;
   
   -----------------------------------------------------------------------------
   -- Function to initialize the array of reset intervals.
   -- 
   -- The general rule is:
   -- array(k) = (k+1)*2*(C_COUNTER_START+1)*TREADY_INTERVAL_STEP*C_COUNTER_CYCLES/size.
   --
   -- Only if any of these elements cannot fit in the integer representation,
   -- this function returns an array:
   -- array(k) = (k+1)*integer'high/size 
   -----------------------------------------------------------------------------
   function F_INIT_RST_INTERVAL_STEP(size : integer) return int_array_t is
      constant STEP_FACTOR : integer 
         := 2*TREADY_INTERVAL_STEP*C_COUNTER_CYCLES;
      constant COUNTER_START_TH : integer := (integer'high/STEP_FACTOR)-1;
     
      variable ret: int_array_t(0 to size-1);
   begin
     
     if C_COUNTER_START < COUNTER_START_TH then
        for k in ret'range loop
           ret(k) := (k+1)*(C_COUNTER_START+1)*STEP_FACTOR/size;
        end loop;
     else
        for k in ret'range loop
           ret(k) := (integer'high/size)*(k+1);
        end loop;
     end if;  
     
     assert ret(0) = 0 report "DUT is not compatible with test settings" severity error;
     
     return ret;
   end function F_INIT_RST_INTERVAL_STEP;
  
   -- Array of tready intervals evaluated in this test
   constant TREADY_INTERVAL_ARRAY : int_array_t(0 to TREADY_INTERVAL_ARRAY_SIZE -1)
      := F_INIT_INT_ARRAY(TREADY_INTERVAL_START, 
                          TREADY_INTERVAL_STEP,
                          TREADY_INTERVAL_ARRAY_SIZE);
     
   -- Array of reset interval evaluated in this test
   constant RST_INTERVAL_ARRAY : int_array_t(0 to RST_INTERVAL_ARRAY_SIZE-1)
      := F_INIT_RST_INTERVAL_STEP(RST_INTERVAL_ARRAY_SIZE);
      
   signal rst_id : integer := 0;
   signal tready_id : integer := 0;
   signal testbegin : std_logic := '1';   
   signal idle_count : integer := 0;
   signal rst_count : integer := 0;   
   signal rst_interval : integer := 0;
   signal tready_interval : integer;
   signal rst : std_logic := not C_RST_ACTIVE_LEVEL;
   signal end_trigger : std_logic := '0';
   signal tready : std_logic := '0';
   signal counter_update : std_logic;
   
begin
   
   reset <= rst;
   test_end <= end_trigger;
   axis_tready <= tready;
   
   rst_interval <= RST_INTERVAL_ARRAY(rst_id);
   tready_interval <= TREADY_INTERVAL_ARRAY(tready_id);
   counter_update <= axis_tvalid and tready;
   
   -----------------------------------------------------------------------------
   -- Process to update the reset and tready intervals with the elements 
   -- of TREADY_INTERVAL_ARRAY and RST_INTERVAL_ARRAY.
   -- This process triggers the test ending after evaluation of all the
   -- combinations.
   -----------------------------------------------------------------------------
   Schedule : process (rst_count) is
   begin
      if rst_count = 0 and testbegin = '0' then
         if rst_id = RST_INTERVAL_ARRAY_SIZE-1 then
            rst_id <= 0;
            if tready_id = TREADY_INTERVAL_ARRAY_SIZE-1 then
               end_trigger <= '1';
            else
               tready_id <= tready_id + 1;
            end if;
         else
            rst_id <= rst_id + 1;
         end if;
     end if;
     
     testbegin <= '0';
   end process Schedule;
   
   Logger : process (rst_id) is
   begin
      report "TB: TEST CASE " &
      "reset_interval " & integer'image(RST_INTERVAL_ARRAY(rst_id)) &
      " tready_interval " & integer'image(TREADY_INTERVAL_ARRAY(tready_id));
      
   end process Logger;
   
   
   -----------------------------------------------------------------------------
   -- Process to generate the resete pulses.
   -----------------------------------------------------------------------------   
   ResetPulse : process (clk) is
   begin
      if rising_edge(clk) then
         if rst_count = 0 then
            rst <= not rst;
            if rst = C_RST_ACTIVE_LEVEL then
               rst_count <= rst_interval;
            end if;
         else
            rst_count <= rst_count-1;
         end if;
      end if;
   end process ResetPulse;
   
   -----------------------------------------------------------------------------
   -- Process to control the AXIS tready port
   -----------------------------------------------------------------------------      
   TreadyPulse : process (clk) is
      variable idle_count_v : integer;
   begin
      if rising_edge(clk) then
         if rst = C_RST_ACTIVE_LEVEL then
            tready <= '0';
            idle_count <= 0;
         else
            if counter_update = '1' then
               idle_count_v := 0;
            else
               idle_count_v := idle_count + 1;
            end if;
            
            idle_count <= idle_count_v;
            
            if idle_count_v >= tready_interval then
               tready <= '1';
            else
               tready <= '0';
            end if;        
         end if;
      end if;
   end process TreadyPulse;

end architecture RTL;
