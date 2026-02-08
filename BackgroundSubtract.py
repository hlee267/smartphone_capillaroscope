from ij import IJ
from ij import WindowManager as wm
from ij import gui
from ij import plugin
from ij.measure import ResultsTable
from ij import process
import os
import csv
import time
import sys

#dir = '/Users/marisamorakis/Library/CloudStorage/OneDrive-JohnsHopkins/Johns Hopkins/Durr Lab/Image Data/20240209'

imp = IJ.getImage()
title = imp.getTitle()

ic = process.ImageConverter(imp)
ic.convertToGray32()
imp2 = imp.duplicate()

IJ.run(imp2, "Gaussian Blur...", "sigma=30")

imp3 = plugin.ImageCalculator.run(imp, imp2, "Divide create 32-bit")
imp.close()
imp2.close()
imp3.show()
ntitle = title.split('.')[0]+'_BS.tif'
imp3.setTitle(ntitle)
#IJ.saveAsTiff(imp3,os.path.join(dir,ntitle))