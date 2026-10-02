#!/usr/bin/env python3
import sys
import time
import serial

def run_uart_commands(commands, timeout=5):
    ser = serial.Serial('/dev/ttyACM0', 115200, timeout=0.2)
    # Drain any existing buffer
    ser.read(ser.in_waiting or 1)
    
    # Send newline to see if prompt is already active
    ser.write(b'\n')
    time.sleep(0.3)
    resp = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    if '# ' not in resp and '$ ' not in resp:
        # Trigger Ctrl+T
        ser.write(b'\x14\n')
        time.sleep(0.5)
        resp += ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    
    for cmd in commands:
        print(f">>> SEND: {cmd}")
        ser.write((cmd + '\n').encode('utf-8'))
        start_time = time.time()
        buf = ""
        while time.time() - start_time < timeout:
            chunk = ser.read(ser.in_waiting or 1).decode('utf-8', errors='ignore')
            if chunk:
                buf += chunk
                sys.stdout.write(chunk)
                sys.stdout.flush()
                # If we see prompt again after command output
                if '# ' in buf[len(cmd):]:
                    break
            else:
                time.sleep(0.05)
        print("\n--- END OF COMMAND ---\n")
    ser.close()

if __name__ == '__main__':
    cmds = sys.argv[1:] if len(sys.argv) > 1 else ['id', 'pwd']
    run_uart_commands(cmds)
