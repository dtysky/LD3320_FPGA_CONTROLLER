library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity VOICE_CLOCK is
port(inclk0:in std_logic;
c0,c1:out std_logic);
end entity;

architecture clkx of VOICE_CLOCK is

begin

c0<=inclk0;
c1<=not inclk0;

end clkx;
