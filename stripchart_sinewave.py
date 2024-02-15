import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import pandas as pd

xsize=800

import time 
import serial 

# configure the serial port 
ser = serial.Serial( 
 port='COM6', 
 baudrate=115200, 
 parity=serial.PARITY_NONE, 
 stopbits=serial.STOPBITS_TWO, 
 bytesize=serial.EIGHTBITS 
) 
 
data_list = []  
def data_gen():
    t = data_gen.t
    while True:
        t+=1
        val = int(ser.readline())
        val= val/10000
        # strin = strin.decode()
        yield t, val
        data_list.append({'time':t,'value':val})

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    return line,

def on_close_figure(event):
    df = pd.DataFrame(data_list)
    df.to_excel("OvenVal.xlsx", index = False)
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(0, 300)
ax.set_xlim(0, 800)
ax.grid()
xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()
