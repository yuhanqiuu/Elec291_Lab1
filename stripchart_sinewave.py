import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math

import serial

xsize=100
   
def data_gen():
    t = data_gen.t
    while True:
        t += 1
        # Read data from serial port (COM5)
        try:
            val = float(ser.readline().decode().strip())
        except ValueError:
            continue  # Skip invalid data
        yield t, val

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
    sys.exit(0)

data_gen.t = -1

# Open serial port
ser = serial.Serial('COM5', 115200)

fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(-100, 100)
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()
