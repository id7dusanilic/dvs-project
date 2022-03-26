library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity avs_sink is
    generic (
        G_PACKET_SIZE       : natural := 4;
        G_READY_PROB        : real := 0.5;
        G_FILE_OUTPUT       : string := "output.txt";
        G_FILE_OUTPUT_REF   : string := "output_ref.txt";
        G_DATA_FORMAT       : string := "bin"
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        data            : in std_logic_vector;
        ready           : out  std_logic;
        valid           : in std_logic;
        last            : in std_logic;
        error_in_data   : out std_logic;
        error_in_last   : out std_logic
    );
end avs_sink;

architecture Test of avs_sink is
    signal c_packet_data : natural range 0 to G_PACKET_SIZE-1;
    signal r_expected_data : std_logic_vector(data'range);
    signal r_rand_ready  : std_logic;
    signal r_rand_valid  : std_logic;
begin
    ready <= r_rand_ready;

    process(reset, clk)
        file f_output               : text open write_mode is G_FILE_OUTPUT;
        variable v_output_line      : line;
        variable v_output_value     : std_logic_vector(data'range);

        file f_output_ref           : text open read_mode is G_FILE_OUTPUT_REF;
        variable v_output_ref_line  : line;
        variable v_output_ref_value : std_logic_vector(data'range);

        variable seed1              : positive;
        variable seed2              : positive;
        variable rand               : real;
        variable started            : std_logic := '0';

    begin
        if (reset = '1') then
            c_packet_data <= 0;
            r_rand_ready <= '0';
            error_in_last <= '0';
            error_in_data <= '0';

            if started='0' then
                if (not endfile(f_output_ref)) then
                    readline(f_output_ref, v_output_ref_line);
                    if G_DATA_FORMAT="bin" then
                        read(v_output_ref_line, v_output_ref_value);
                    elsif G_DATA_FORMAT="hex" then
                        hread(v_output_ref_line, v_output_ref_value);
                    else
                        assert false report "Invalid data format" severity error;
                    end if;

                    r_expected_data <= v_output_ref_value;
                end if;
                started := '1';
            end if;
            seed1 := 222;
            seed2 := 888;

        elsif (rising_edge(clk)) then

            if (not endfile(f_output_ref)) then
                r_rand_valid <= '1';
            else
                r_rand_valid <= '0';
            end if;

            uniform(seed1, seed2, rand);

            if (rand<G_READY_PROB) then
                r_rand_ready <= '1';
            else
                r_rand_ready <= '0';
            end if;

            if (r_rand_ready = '1' and valid = '1') then
                if (not endfile(f_output_ref)) then
                    readline(f_output_ref, v_output_ref_line);
                    if G_DATA_FORMAT="bin" then
                        read(v_output_ref_line, v_output_ref_value);
                    elsif G_DATA_FORMAT="hex" then
                        hread(v_output_ref_line, v_output_ref_value);
                    else
                        assert false report "Invalid data format" severity error;
                    end if;
                    r_expected_data <= v_output_ref_value;
                else
                    r_rand_valid <= '0';
                end if;
                if (data = r_expected_data) then
                    error_in_data <= '0';
                else
                    error_in_data <= '1';
                end if;
            end if;

            if (r_rand_ready = '1' and valid = '1') then

                if (c_packet_data < G_PACKET_SIZE - 1) then
                    if (last = '1') then
                        error_in_last <= '1';
                    end if;
                    c_packet_data <= c_packet_data + 1;
                else
                    if (last = '0') then
                        error_in_last <= '1';
                    end if;
                    c_packet_data <= 0;
                end if;

                v_output_value := data;
                if G_DATA_FORMAT="bin" then
                    write(v_output_line, data);
                elsif G_DATA_FORMAT="hex" then
                    hwrite(v_output_line, data);
                else
                    assert false report "Invalid data format" severity error;
                end if;
                writeline(f_output, v_output_line);

            end if;

        end if;
    end process;

end Test;
