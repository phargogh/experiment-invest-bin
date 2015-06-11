import types

# still need a generic raster-writing function.

def uniform(value):
    pass

class RasterFactory(object)
    def __init__(self, projection, datatype, nodata, n_rows, n_cols, geotransform)
        self.proj = projection
        self.datatype = datatype
        self.nodata_val = nodata
        self.rows = n_rows
        self.cols = n_cols
        self.gt = geotransform

        this_module = sys.modules[__name__]
        for attrname in dir(this_module):
            attr = getattr(this_module, attrname)
            if type(attr) is types.FunctionType:
                setattr(self, attrname, attr)

    def _write_raster(matrix, uri, projection=None, datatype=None, nodata=None, n_rows=None, n_cols=None, geotransform=None):
        # write the raster to the target URI
        # if any of the parameters aren't set to None, use this value instead
        # of what's already provided by the Factory class.
        pass


