from ij import IJ
from ij import WindowManager as wm
from ij import gui
from ij import plugin
from ij.measure import ResultsTable
from ij import process
from ij.plugin import ChannelSplitter
import os
import csv
import time
import sys

#dir = '/Users/marisamorakis/Library/CloudStorage/OneDrive-JohnsHopkins/Johns Hopkins/Durr Lab/Image Data/20240209'

imp = IJ.getImage()
title = imp.getTitle()

# use only the green channel
channels = ChannelSplitter.split(imp)
green = channels[1]

ic = process.ImageConverter(green)
ic.convertToGray32()
imp2 = green.duplicate()

IJ.run(imp2, "Gaussian Blur...", "sigma=50")

imp3 = plugin.ImageCalculator.run(green, imp2, "Divide create 32-bit")
green.close()
imp2.close()
imp3.show()
ntitle = title.split('.')[0]+'_BS.tif'
imp3.setTitle(ntitle)
#IJ.saveAsTiff(imp3,os.path.join(dir,ntitle))