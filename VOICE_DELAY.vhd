library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

entity VOICE_DELAY is
port
	(
		clk:in std_logic;
		start:in std_logic:='0';
		total:in std_logic_vector(7 downto 0);
		finish:out std_logic:='1'
	);
end entity;


architecture delayx of VOICE_DELAY is

signal delay_total:integer range 0 to 511:=0;
signal start_last:std_logic;

begin

process(clk)

variable con:integer range 0 to 400:=0;

begin

	if clk'event and clk='1' then
	
		start_last<=start;
		if start_last='0' and start='1' then
			con:=1;
			delay_total<=conv_integer(total);
			finish<='0';
		end if;
		
		if con=400 then
			
			if delay_total=0 then
				finish<='1';
				con:=0;
			else
				delay_total<=delay_total-1;
				con:=1;
			end if;
			
		elsif con>0 then
			con:=con+1;
		
		end if;
		
	end if;

end process;

end delayx;

		
		