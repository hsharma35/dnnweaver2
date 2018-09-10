import re

if __name__ == "__main__":
    log_file = './log/vivado.log'
    parsed_log_file = './log/vivado_parsed.log'
    warn = r"WARNING:\s*\[Synth \d-\d*\]"
    ip = r"\/sources_1\/"
    with open(log_file, 'r') as rf:
        with open(parsed_log_file, 'w') as wf:
            for line in rf:
                if re.search(warn, line) and not re.search(ip, line):
                    wf.write(line)
