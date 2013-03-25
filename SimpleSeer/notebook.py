

def load_ipython_extension(ipython):
    
    from .Session import Session
    from SimpleCV import Display, Image, ImageSet, Color
    from .realtime import ChannelManager, Channel
    from . import models as M
    import zmq
    
    from .util import load_plugins
    
    load_plugins()
    
    s = Session(".")
    ipython.push(
        dict(
            Frame = M.Frame,
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
            display=Display(displaytype="notebook"), 
            cm=ChannelManager(),
            Channel=Channel),
        interactive=True)
    print 'SimpleSeer ipython extension loaded ok'

def unload_ipython_extension(ipython):
    # If you want your extension to be unloadable, put that logic here.
    pass

