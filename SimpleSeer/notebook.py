from .Session import Session
from SimpleCV import Display, Image, ImageSet, Color
from .realtime import ChannelManager, Channel
from . import models as M
from .util import load_plugins

def load_ipython_extension(ipython):
    
    load_plugins()
    
    s = Session(".")
    
    ipython.push(
        contextDict(),
        interactive=True)
    print 'SimpleSeer ipython extension loaded ok'

def contextDict():
    # Split this into a function so it can be tested outside ipython load
    import bson
    return dict(Frame = M.Frame,
                OLAP = M.OLAP,
                Chart = M.Chart,
                FrameSet = M.FrameSet,
                Inspection = M.Inspection,
                Measurement = M.Measurement,
                M=M,
                Image = Image,
                ImageSet = ImageSet,
                Dashboard= M.Dashboard,
                Color = Color,
                ObjectId = bson.ObjectId,
                display=Display(displaytype="notebook"), 
                cm=ChannelManager(),
                Channel=Channel)    

def unload_ipython_extension(ipython):
    # If you want your extension to be unloadable, put that logic here.
    pass

