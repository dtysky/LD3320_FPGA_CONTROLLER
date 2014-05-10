library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;


entity VOICE is 
port
	(
		start:in std_logic;
		clk:in std_logic;
		clk_voice:out std_logic;
		n_wr,n_cs,n_rd,n_rst:out std_logic:='1';
		n_int:in std_logic:='0';
		add_en:out std_logic:='0';
		data_voice:inout std_logic_vector(7 downto 0);
		voice_result:out std_logic_vector(7 downto 0):=x"00";
		reco_rqu:in std_logic:='0';
		reco_fin:out std_logic:='0'
	);
end entity;

architecture voicex of VOICE is

component voice_clock is
port
	(
		inclk0:in std_logic;
		c0:out std_logic;
		c1:out std_logic
	);
end component;

component voice_rom_init is
port
	(
		clock:in std_logic;
		address:in std_logic_vector(5 downto 0);
		q:out std_logic_vector(15 downto 0)
	);
end component;

component list is
port
	(
		clock:in std_logic;
		address:in std_logic_vector(8 downto 0);
		q:out std_logic_vector(7 downto 0)
	);
end component;

component VOICE_DELAY is
port
	(
		clk:in std_logic;
		start:in std_logic:='0';
		total:in std_logic_vector(7 downto 0);
		finish:out std_logic:='1'
	);
end component;


-------------------时钟、40MHz---------------------
signal clk_self,clk_out:std_logic;

-----------------------复位------------------------
signal reset:std_logic:='0';

--------------------初始化ROM----------------------
signal rom_init_addr:std_logic_vector(5 downto 0);
signal rom_init_data:std_logic_vector(15 downto 0);

---------------------列表ROM-----------------------
signal rom_list_addr:std_logic_vector(8 downto 0);
signal rom_list_data:std_logic_vector(7 downto 0);

-----------------------延时------------------------
signal delay_start,delay_finish:std_logic:='0';
signal delay_total:std_logic_vector(7 downto 0);

----------------------配置状态----------------------
signal init_done,list_done,all_wait,all_done,all_done_last:std_logic:='0';

----------------------识别状态----------------------
signal reco_allow,reco_allow_last,reco_start:std_logic:='0';
signal reco_rqu_last:std_logic:='0';
signal n_int_last:std_logic:='1';

signal add_en_s:std_logic:='1';



begin

clk_voice<=clk_self;
add_en<=add_en_s;

VOICE_CLOCKX:voice_clock port map(inclk0=>clk,c0=>clk_self,c1=>clk_out);

VOICE_ROM_INITX:voice_rom_init port map(clock=>clk_out,address=>rom_init_addr,q=>rom_init_data);

VOICE_ROM_LIST:list port map(clock=>clk_out,address=>rom_list_addr,q=>rom_list_data);

VOICE_DLLAYX:voice_delay port map(clk=>clk_self,start=>delay_start,finish=>delay_finish,total=>delay_total);


process(clk_self,reset)

variable con_reset:integer range 0 to 127:=0;

variable con_init_start:integer range 0 to 2047:=0;
variable con:integer range 0 to 5:=0;
variable con_total:integer range 0 to 26:=0;
variable con_type:integer range 0 to 31:=0;
variable con_init_fin_start:integer range 0 to 3:=0;



begin

	if clk_self'event and clk_self='1' then
	
--------------------复位-----------------------	
		if con_reset=127 then
			reset<='1';
		end if;
		
		if reset='1' then
			con_reset:=0;
			reset<='0';
			reco_fin<='0';
			init_done<='0';
			list_done<='0';
			all_wait<='0';
			all_done<='0';
			reco_allow<='0';
			rom_init_addr<="000000";
			rom_list_addr<="000000000";
			con_init_start:=0;
		end if;
			

		
---------------------初始化----------------------
		if start='1' then
		
			if con_init_start=2047 then
				con_init_start:=2047;
			else
				con_init_start:=con_init_start+1;
				con:=0;
				con_type:=0;
				con_total:=0;
				con_init_fin_start:=0;
			end if;
			
		end if;
		
		if con_init_start=500 then
			n_rst<='0';
		elsif con_init_start=1000 then
			n_rst<='1';
		elsif con_init_start=1500 then
			n_cs<='0';
		elsif con_init_start=2000 then
			n_cs<='1';
			delay_start<='1';
			delay_total<=x"5F";
		end if;
	
--------------------初始化---------------------
		if con_init_start=2047 and init_done='0' and delay_finish='1' then
		
			if con=5 then
				con:=0;
			elsif con=0 then
				
				if con_total=26 then
					init_done<='1';
					con:=0;
					con_type:=0;
					con_total:=0;
				else
					con:=con+1;
				end if;
				
			else
				con:=con+1;
			end if;
			
-------------------------------------------------------
			if con_total=0 or con_total=2 then
			
				if con=1 then
					delay_start<='0';
				
					if con_type=0 then
						add_en_s<='1';
						data_voice<=x"06";
					else
						add_en_s<='0';
						
						data_voice<="ZZZZZZZZ";
					end if;
					
				elsif con=2 then
					n_cs<='0';
				elsif con=3 then
				
					if con_type=0 then
						n_wr<='0';
					else
						n_rd<='0';
					end if;
					
				elsif con=4 then
				
					if add_en_s='0' then
						delay_total<=x"0A";
						delay_start<='1';
					end if;
					
					if con_type=0 then
						n_wr<='1';
					else
						n_rd<='1';
					end if;
					
				elsif con=5 then
					n_cs<='1';
					
					if con_type=1 then
						con_type:=0;
						con_total:=con_total+1;
					else
						con_type:=con_type+1;
					end if;

				end if;
				
			
-------------------------------------------------------
			else
			
				if con=1 then
					delay_start<='0';
				
					if con_type=0 then
						add_en_s<='1';
						data_voice<=rom_init_data(15 downto 8);
					else
						add_en_s<='0';
						data_voice<=rom_init_data(7 downto 0);
						rom_init_addr<=rom_init_addr+1;
					end if;
					
				elsif con=2 then
					n_cs<='0';
				elsif con=3 then
					n_wr<='0';
				elsif con=4 then
					n_wr<='1';
					delay_total<=x"0A";
					delay_start<='1';
				elsif con=5 then
					n_cs<='1';
					
					if con_type=1 then
						con_type:=0;
						con_total:=con_total+1;
					else
						con_type:=con_type+1;
					end if;

				end if;
		
			end if;
		
		end if;
		
-------------------待识别列表写入----------------
		if init_done='1' and list_done='0' and delay_finish='1' then
			
			if con=0 then
				delay_start<='0';
				con:=con+1;
				
			elsif con=1 then
			
				if con_type=0 then
					
					add_en_s<='1';
					data_voice<=x"B2";
					con:=con+1;
					
				elsif con_type=10 then
				
					add_en_s<='0';
					data_voice<="ZZZZZZZZ";
					con:=con+1;
				
				elsif con_type=1 then
				
					if rom_list_data=x"FF" then
					
						con_type:=20;
						--list_done<='1';
						delay_total<=x"5F";
						delay_start<='1';
						con:=0;
						--con_type:=0;
					else
						add_en_s<='1';
						data_voice<=x"C1";
						con:=con+1;
						con_type:=2;
					end if;
					
				elsif con_type=20 then
				
					add_en_s<='1';
					data_voice<=x"BF";
					con:=con+1;
					
				elsif con_type=21 then
					
					add_en_s<='0';
					data_voice<="ZZZZZZZZ";
					con:=con+1;
					
				elsif con_type=2 then

					add_en_s<='0';
					data_voice<=rom_list_data;
					con:=con+1;
					con_type:=12;
					
				elsif con_type=12 then
				
					add_en_s<='1';
					data_voice<=x"C3";
					con:=con+1;
					con_type:=13;
					
				elsif con_type=13 then
				
					add_en_s<='0';
					data_voice<=x"00";
					con:=con+1;
					con_type:=14;
				elsif con_type=14 then
				
					add_en_s<='1';
					data_voice<=x"08";
					con:=con+1;
					con_type:=15;
					
				elsif con_type=15 then
				
					add_en_s<='0';
					data_voice<=x"04";
					con:=con+1;
					con_type:=16;
					
				elsif con_type=16 then
				
					add_en_s<='1';
					data_voice<=x"08";
					con:=con+1;
					con_type:=17;
					
				elsif con_type=17 then
				
					add_en_s<='0';
					data_voice<=x"00";
					con:=con+1;
					con_type:=3;
					
				elsif con_type=3 then
				
					add_en_s<='1';
					data_voice<=x"05";
					con:=con+1;
					con_type:=11;
					rom_list_addr<=rom_list_addr+1;
					
				elsif con_type=4 then
					
					add_en_s<='1';
					data_voice<=x"B9";
					con:=con+1;
					con_type:=5;
					rom_list_addr<=rom_list_addr+1;
				
				elsif con_type=5 then
					
					add_en_s<='0';
					data_voice<=rom_list_data;
					con:=con+1;
					con_type:=6;
					
				elsif con_type=6 then
					
					add_en_s<='1';
					data_voice<=x"B2";
					con:=con+1;
					con_type:=7;
					
				elsif con_type=7 then
					
					add_en_s<='0';
					data_voice<=x"FF";
					con:=con+1;
					con_type:=8;
					
				elsif con_type=8 then
					
					add_en_s<='1';
					data_voice<=x"37";
					con:=con+1;
					con_type:=9;
					
				elsif con_type=9 then
					
					add_en_s<='0';
					data_voice<=x"04";
					con:=con+1;
					con_type:=0;
					rom_list_addr<=rom_list_addr+1;
					
				elsif con_type=11 then
					
					if rom_list_data=x"FF" then
						con_type:=4;
						con:=0;
					else
					
						add_en_s<='0';
						data_voice<=rom_list_data;
						rom_list_addr<=rom_list_addr+1;
						con:=con+1;
					end if;
				
				end if;
				
			elsif con=2 then
				n_cs<='0';
				con:=con+1;
				
			elsif con=3 then
				con:=con+1;
			
				if con_type=10 or con_type=21 then
					n_rd<='0';
				else
					n_wr<='0';
				end if;
				
			elsif con=4 then
				con:=con+1;
				
				if add_en_s='0' and con_type/=11 then
					delay_total<=x"01";
					delay_start<='1';
				end if;
				
				if con_type=21 or con_type=10 then
					n_rd<='1';	
				else 
					n_wr<='1';
				end if;
				
			elsif con=5 then
				n_cs<='1';
				con:=0;

				if con_type=10 then
				
					if data_voice=x"21" then
						con_type:=1;
					else
						delay_total<=x"0A";
						delay_start<='1';
						con_type:=0;
						con_reset:=con_reset+1;
					end if;
					
				elsif	con_type=0 then
					con_type:=10;
				elsif con_type=20 then
					con_type:=21;
				elsif con_type=21 then
					
					if data_voice=x"31" then
						con_type:=0;
						list_done<='1';
						con:=0;
						con_type:=0;
					else
						reset<='1';
					end if;
					
				end if;
			
			end if;
		
		end if;
			
		
-------------------------识别准备------------------------
		
		reco_rqu_last<=reco_rqu;
		if reco_rqu_last='0' and reco_rqu='1' then
			reco_start<='1';
		end if;
		
		
		if list_done='1' and all_wait='0' and reco_start='1' and delay_finish='1' then
		
			if con_init_fin_start=3 then
				con_init_fin_start:=3;
			else
				rom_init_addr<="100000";
				con_init_fin_start:=con_init_fin_start+1;
			end if;
		
			if con_init_fin_start=3 then
			
				if con=5 then
					con:=0;
					
				elsif con=0 then
				
					if con_total=5 then
						all_wait<='1';
						reco_start<='0';
						con:=0;
						con_type:=0;
						con_total:=0;
						con_reset:=0;
					elsif con_total=0 then
						con:=con+1;
					else
						con:=con+1;
					end if;
					
				else
					con:=con+1;
				end if;
				
				
				if con=0 then
					delay_start<='0';
					
				elsif con=1 then
				
					if con_type=0 then
						add_en_s<='1';
						data_voice<=rom_init_data(15 downto 8);
					else
						add_en_s<='0';
						data_voice<=rom_init_data(7 downto 0);
						rom_init_addr<=rom_init_addr+1;
					end if;
				
					
				elsif con=2 then
					n_cs<='0';
				elsif con=3 then
					n_wr<='0';
				elsif con=4 then
					n_wr<='1';
					
					if add_en_s='0' then
						delay_total<=x"01";
						delay_start<='1';
					end if;
					
				elsif con=5 then
					n_cs<='1';
					
					if con_type=1 then
						con_type:=0;
						con_total:=con_total+1;
					else
						con_type:=con_type+1;
					end if;
					
				end if;
				
			end if;
			
		end if;
					
	
---------------------------识别--------------------------

		if all_wait='1' and delay_finish='1' then
			
			if con=5 then
				con:=0;
			elsif con=0 then
			
				if con_total=7 then
				
					con_total:=0;
					con_type:=0;
					con:=0;
					all_wait<='0';
					all_done<='1';
				else
					con:=con+1;
				end if;
				
			else
				con:=con+1;
				
			end if;
			
			if con=0 then
				delay_start<='0';
				
			elsif con=1 then
			
				if con_type=0 then
					add_en_s<='1';
					
					if con_total=0 then
						data_voice<=x"B2";
					elsif con_total=3 then
						data_voice<=x"BF";
					else
						data_voice<=rom_init_data(15 downto 8);
					end if;
					
				else
					add_en_s<='0';
					
					if con_total=0 or con_total=3 then
						data_voice<="ZZZZZZZZ";
					else
						data_voice<=rom_init_data(7 downto 0);
						rom_init_addr<=rom_init_addr+1;
					end if;
					
				end if;
			
			elsif con=2 then
				n_cs<='0';
				
			elsif con=3 then
			
				if (con_total=0 or con_total=3) and con_type=1 then
					n_rd<='0';
				else
					n_wr<='0';
				end if;
				
			elsif con=4 then
				
				if (con_total=0 or con_total=3) and con_type=1 then
					n_rd<='1';
				else
					n_wr<='1';
				end if;
					
				if add_en_s='0' then
					
					if con_total=2 then
						delay_total<=x"05";
					else
						delay_total<=x"01";
					end if;
					
					delay_start<='1';
				end if;
					
			elsif con=5 then
				n_cs<='1';
				
				if con_total=0 and con_type=1 then
					
					if data_voice=x"21" then
						con_total:=con_total+1;
					else
						con_reset:=con_reset+1;
						con_total:=0;
					end if;
				
				elsif con_total=3 and con_type=1 then
					
					if data_voice=x"31" then
						con_total:=con_total+1;
					else
						reco_fin<='1';
						data_voice<=x"FF";
						reset<='1';
					end if;			
			
				elsif con_type=1 then
					con_total:=con_total+1;
				
				end if;
				
				if con_type=1 then
					con_type:=0;
				else
					con_type:=con_type+1;
				end if;
				
			end if;
			
		end if;
		
		
-----------------------识别结果---------------------

		if all_done='1' and delay_finish='1' then
			
			n_int_last<=n_int;
			if n_int_last='1' and n_int='0' then
				reco_allow<='1';
			end if;
			
		end if;
		
		reco_allow_last<=reco_allow;
		if reco_allow_last='1' and reco_allow='0' then
			reco_fin<='0';
		end if;
	
		if reco_allow='1' then
			
			if con=5 then
				con:=0;
			else
				con:=con+1;
			end if;
			
			
			if con=0 then
				
				if con_total=6 then
					reco_allow<='0';
					all_done<='0';
					con:=0;
					con_type:=0;
					con_total:=0;
				end if;
			
			elsif con=1 then
				
				if con_type=0 then
					add_en_s<='1';
				
					if con_total=0 then
						data_voice<=x"29";
					elsif con_total=1 then
						data_voice<=x"02";
					elsif con_total=2 then
						data_voice<=x"BF";
					elsif con_total=3 then
						data_voice<=x"2B";
					elsif con_total=4 then
						data_voice<=x"BA";
					elsif con_total=5 then
						data_voice<=x"C5";
					end if;
				
				else
					add_en_s<='0';
					
					if con_total<2 then
						data_voice<=x"00";
					else
						data_voice<="ZZZZZZZZ";
					end if;
					
				end if;
				
			elsif con=2 then
				n_cs<='0';
			
			elsif con=3 then
				
				if con_total>1 and con_type=1 then
					n_rd<='0';
				else
					n_wr<='0';
				end if;
			
			elsif con=4 then
				
				if con_total>1 and con_type=1 then
					n_rd<='1';
				else
					n_wr<='1';
				end if;
			
			elsif con=5 then
				n_cs<='1';
				
				if con_type=1 then
					con_type:=0;
				
					if con_total<2 then
						con_total:=con_total+1;
					elsif con_total=2 and data_voice=x"35" then
						con_total:=con_total+1;
					elsif con_total=3 and data_voice(3)='0' then
						con_total:=con_total+1;
					elsif con_total=4 then
						
						if data_voice>x"00" and data_voice<x"05" then
							con_total:=con_total+1;
						else
							voice_result<=x"FD";
							reco_allow<='0';
							reco_fin<='1';
							all_done<='0';
							con:=0;
							con_type:=0;
							con_total:=0;
						end if;
						
					elsif con_total=5 then
						reco_fin<='1';
						voice_result<=data_voice;
						con_total:=con_total+1;
					else
						reset<='1';
					end if;

				else
					con_type:=con_type+1;
					
				end if;
				
				
			end if;
		
		end if;
				
				
	end if;

	
end process;


end voicex;
		
	