library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

--------------------------------------------------------------------------------
-- Top level entity of test bench.
--------------------------------------------------------------------------------
entity tb is
end entity tb;

architecture RTL of tb is
   constant RST_ACTIVE_LEVEL : std_logic := '0';
   constant C_AXIS_TDATA_WIDTH : integer := 32;
   constant C_AXIS_TUSER_WIDTH : integer := 5;
   constant CLOCK_PERIOD_NS : time := 1ns;
   constant COUNTER_START_VALUE : integer := 1000;
   constant MAX_CYCLES : integer := 5;
    
   component decreasingCounter
      generic(
         C_START_VALUE      : integer := 16#7FFFFFFF#;
         C_MAX_CYCLES       : integer := 5;
         C_AXIS_TDATA_WIDTH : integer := 32;
         C_AXIS_TUSER_WIDTH : integer := 5
      );
      port(
         M_AXIS_ACLK    : in  std_logic := '0';
         M_AXIS_ARESETN : in  std_logic := not RST_ACTIVE_LEVEL;
         M_AXIS_TVALID  : out std_logic;
         M_AXIS_TDATA   : out std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
         M_AXIS_TLAST   : out std_logic;
         M_AXIS_TUSER   : out std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
         M_AXIS_TREADY  : in  std_logic
      );
   end component decreasingCounter;   
   
   component monitor
      generic(
         C_AXIS_TDATA_WIDTH : integer := 32;
         C_AXIS_TUSER_WIDTH : integer := 5
      );
      port(
         err_count      : out integer;
         tready_in      : in  std_logic;
         S_AXIS_ACLK    : in  std_logic;
         S_AXIS_ARESETN : in  std_logic;
         S_AXIS_TVALID  : in  std_logic;
         S_AXIS_TDATA   : in  std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
         S_AXIS_TLAST   : in  std_logic;
         S_AXIS_TUSER   : in  std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
         S_AXIS_TREADY  : out std_logic
      );
   end component monitor;
   
   component driver
      generic(
         C_RST_ACTIVE_LEVEL : std_logic := '0';
         C_COUNTER_START    : integer;
         C_COUNTER_CYCLES : integer
      );
      port(
         clk         : in  std_logic;
         reset       : out std_logic;
         test_end    : out std_logic;
         axis_tready : out std_logic;
         axis_tvalid : in  std_logic
      );
   end component driver;
   
   signal err_count : integer;
   signal test_end : std_logic;
   signal tready : std_logic;

   signal AXIS_ACLK    : std_logic := '0';
   signal AXIS_ARESETN : std_logic := not RST_ACTIVE_LEVEL;
   signal AXIS_TVALID  : std_logic;
   signal AXIS_TDATA   : std_logic_vector(C_AXIS_TDATA_WIDTH-1 downto 0);
   signal AXIS_TLAST   : std_logic;
   signal AXIS_TUSER   : std_logic_vector(C_AXIS_TUSER_WIDTH-1 downto 0);
   signal AXIS_TREADY  : std_logic := '1';
begin
   -- Generate the clock source.
   AXIS_ACLK <= not AXIS_ACLK after CLOCK_PERIOD_NS/2;
   
   -----------------------------------------------------------------------------
   -- Device Under Test.
   -----------------------------------------------------------------------------   
   DUT: decreasingCounter
      generic map(
         C_START_VALUE      => COUNTER_START_VALUE,
         C_MAX_CYCLES       => MAX_CYCLES
      ) 
      port map(
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => AXIS_TVALID,
         M_AXIS_TDATA   => AXIS_TDATA,
         M_AXIS_TLAST   => AXIS_TLAST,
         M_AXIS_TUSER   => AXIS_TUSER,
         M_AXIS_TREADY  => AXIS_TREADY
      );

   -----------------------------------------------------------------------------
   -- This component manager the test by generating the input stimuli 
   -----------------------------------------------------------------------------       
   TB_DRIVER : driver
      generic map(
         C_COUNTER_START => COUNTER_START_VALUE,
         C_COUNTER_CYCLES =>  MAX_CYCLES
      ) 
      port map(
         clk => AXIS_ACLK,
         reset => AXIS_ARESETN,
         test_end => test_end,
         axis_tready => tready,
         axis_tvalid => AXIS_TVALID
      );

   -----------------------------------------------------------------------------
   -- This component monitors test DUT output against reference.
   -----------------------------------------------------------------------------     
   TB_MONITOR : monitor
      port map(
         err_count      => err_count,
         tready_in      => tready,
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => AXIS_TVALID,
         S_AXIS_TDATA   => AXIS_TDATA,
         S_AXIS_TLAST   => AXIS_TLAST,
         S_AXIS_TUSER   => AXIS_TUSER,
         S_AXIS_TREADY  => AXIS_TREADY
      );
      
   -----------------------------------------------------------------------------
   -- Process to report test result and finish the simulation.
   -----------------------------------------------------------------------------        
   ResultReport : process(test_end) is
   begin
      if rising_edge(test_end) then
         report "Test Done!";
         assert err_count = 0 report "TEST FAILED with " & 
            integer'image(err_count) & " errors" severity error;
         
         finish;   
      end if;
   end process ResultReport; 
   

  
end architecture RTL;
