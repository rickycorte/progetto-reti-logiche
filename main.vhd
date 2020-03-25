----------------------------------------------------------------------------------
-- Progetto Reti Logiche 
-- AA 2019-2020 Politecnico Di Milano
-- 
--
--
-- Target Devices: FPGA xc7a200tfbg484-1 
-- Tool Versions: Vivado Webpack 2019.2
-- 
----------------------------------------------------------------------------------

--
-- Dea Freya che sei nell'alto dei cieli
-- al posto di darmi l'amore che non mi serve
-- concedi a questo codice il tuo affetto
-- affinche sia sintetizzabile e non vada in errore 
-- Amen
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    Port ( i_clk     : in STD_LOGIC;
           i_start   : in STD_LOGIC;
           i_rst     : in STD_LOGIC;
           i_data    : in STD_LOGIC_VECTOR (7 downto 0);
           o_address : out STD_LOGIC_VECTOR (15 downto 0);
           o_done    : out STD_LOGIC;
           o_en      : out STD_LOGIC;
           o_we      : out STD_LOGIC;
           o_data    : out STD_LOGIC_VECTOR (7 downto 0)
          );
end project_reti_logiche;


architecture Behavioral of project_reti_logiche is
  
    signal cnt         : UNSIGNED (3 downto 0);
    signal cnt_fixed   : UNSIGNED (3 downto 0);
    signal done        : STD_LOGIC;        
    signal wz          : UNSIGNED(63 downto 0);
    signal result      : STD_LOGIC_VECTOR (7 downto 0);
    signal cache_ready : STD_LOGIC;     
    
begin

    -- contatore a 4 bit che conta da 0 a 10 e poi si ferma
    -- serve a scandire le operazioni 0-7 -> lettura ram, 8 -> lettura + codifica addr, 9 -> scrittura su ram + done
    -- il conteggio e' duplicato per poter tenere indietro di 1 rispetto il valore reale del contatore
    -- viene inoltre gestito il reset + la cache delle wz non che eventuali condizioni di errori/reset su i_rst e i_start
    -- il reset e' asincrono come i_start = 0 che viene considerato quasi un reset (salvo per il mantenimento dell'eventuale cache)
    -- all'ottavo "step" quando tutte le wz sono caricate il contatore attiva lo stato di cache che puo essere usata nelle succesive operazioni partendo dallo stato 8  
    COUNT : process(i_clk, i_rst, i_start, done, cache_ready)
    begin  
        -- reset
        if i_rst = '1' or i_start = '0' then
            if cache_ready = '0' or i_rst = '1' then
                cnt <= "0000";
                cache_ready <= '0';
            else
                cnt <= "1000";
            end if;
                
            cnt_fixed <= "0000";
            done <= '0'; 
        elsif falling_edge(i_clk) and done = '0' then
            if cnt_fixed = 8 then -- viene settato alla fine dell'ottavo ciclo di operazione
                done <= '1';
                cache_ready <= '1';
            end if;
            cnt_fixed <= cnt;
            cnt <= cnt+1;                                   
        end if;
    end process;

    -- carica nel registro di 64bit le varie working-zone a seconda dello step a cui si trova il contatore
    -- 1 op/clock, addr della ram e' settato asincronamente in base al contatore (interfaccia uscita)
    -- sincronizatto sul fronte di discesa del clock per assicurarsi che il valore di usicita della RAM sia cambiato e stabile
    LOADWZ : process(i_clk, i_rst, i_data, cnt_fixed, i_start, cache_ready)
    begin
    
        if not(i_rst = '1' or i_start = '0') and cache_ready = '0' then        
            -- save val in reg
            if falling_edge(i_clk) then
                case cnt_fixed is
                    when "0000" => wz(7 downto 0) <= unsigned(i_data);
                    when "0001" => wz(15 downto 8) <= unsigned(i_data);
                    when "0010" => wz(23 downto 16) <= unsigned(i_data);
                    when "0011" => wz(31 downto 24) <= unsigned(i_data);
                    when "0100" => wz(39 downto 32) <= unsigned(i_data);
                    when "0101" => wz(47 downto 40) <= unsigned(i_data);
                    when "0110" => wz(55 downto 48) <= unsigned(i_data);
                    when "0111" => wz(63 downto 56) <= unsigned(i_data);
                    when others => null;
                end case;      
            end if;
                     
        end if;
    
    end process;

    -- processa in ordine di priorita (wz 0: priorita massima, 7: priorita minima) e codifica il risultato
    -- in caso di overlap delle wz viene scelta la prima a seconda della priorita che ha e non in base alla vicinanza
    -- e' inoltre virtualmente supportata la codifica di wz a 8bit anche se la specifica garantisce indirizzi a 7bit
    -- in caso di wz a 8bit che si suppone non vengano mai passate a questo componente, vengono ugualmente codificate in modo corretto
    -- viene pero violato il vincolo di avere il primo bit = 0 in caso l'indirizzo da codificare abbia il primo bit a 1 e non appartenga a nessuna wz
    CMP: process(i_clk, i_data, cnt_fixed)
        variable offset8 : UNSIGNED(7 downto 0);
        variable found   : STD_LOGIC;
    begin
        if falling_edge(i_clk) and cnt_fixed = "1000" then       
            found := '0';
            
            for I in 0 to 7 loop
                offset8 := unsigned(i_data) - wz(I*8 +7 downto I*8);       
                    
                if offset8 < 4 and found = '0' then
                    found := '1';
                    case offset8(1 downto 0) is
                        when "00" => result <= "1" & std_logic_vector(to_unsigned(I,3)) & "0001";
                        when "01" => result <= "1" & std_logic_vector(to_unsigned(I,3)) & "0010";
                        when "10" => result <= "1" & std_logic_vector(to_unsigned(I,3)) & "0100";
                        when "11" => result <= "1" & std_logic_vector(to_unsigned(I,3)) & "1000";
                        when others => null;
                    end case;  
                end if;
                               
            end loop;
                
            if found = '0' then
                result <= i_data;
            end if;
            
        end if;      
    
    end process;
               

   -- out interface

   o_en <= i_start;
   o_we <= '1' when cnt_fixed > 8 else '0';
   o_done <= done;
   o_data <= result when cnt_fixed > 7 else (others => '-'); 

   o_address <= "000000000000" & std_logic_vector(cnt_fixed) when cnt_fixed < 10 else (others=> '-');
    
end Behavioral;
