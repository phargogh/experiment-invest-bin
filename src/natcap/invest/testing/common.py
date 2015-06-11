def assertRastersEqual(a_uri, b_uri):
    """Tests if datasets a and b are 'almost equal' to each other on a per
    pixel basis

    This assertion method asserts the equality of these raster
    characteristics:
        + Raster height and width

        + The number of layers in the raster

        + Each pixel value, out to a precision of 7 decimal places if the\
        pixel value is a float.


    Args:
        a_uri (string): a URI to a GDAL dataset
        b_uri (string): a URI to a GDAL dataset

    Returns:
        Nothing.

    Raises:
        IOError: Raised when one of the input files is not found on disk.

        AssertionError: Raised when the two rasters are found to be not\
        equal to each other.

    """

    LOGGER.debug('Asserting datasets A: %s, B: %s', a_uri, b_uri)

    for uri in [a_uri, b_uri]:
        if not os.path.exists(uri):
            raise IOError('File "%s" not found on disk' % uri)

    a_dataset = gdal.Open(a_uri)
    b_dataset = gdal.Open(b_uri)

    self.assertEqual(a_dataset.RasterXSize, b_dataset.RasterXSize,
        "x dimensions are different a=%s, second=%s" %
        (a_dataset.RasterXSize, b_dataset.RasterXSize))
    self.assertEqual(a_dataset.RasterYSize, b_dataset.RasterYSize,
        "y dimensions are different a=%s, second=%s" %
        (a_dataset.RasterYSize, b_dataset.RasterYSize))
    self.assertEqual(a_dataset.RasterCount, b_dataset.RasterCount,
        "different number of rasters a=%s, b=%s" % (
        (a_dataset.RasterCount, b_dataset.RasterCount)))

    for band_number in range(1, a_dataset.RasterCount + 1):
        band_a = a_dataset.GetRasterBand(band_number)
        band_b = b_dataset.GetRasterBand(band_number)

        a_array = band_a.ReadAsArray(0, 0, band_a.XSize, band_a.YSize)
        b_array = band_b.ReadAsArray(0, 0, band_b.XSize, band_b.YSize)

        try:
            numpy.testing.assert_array_almost_equal(a_array, b_array)
        except AssertionError:
            for row_index in xrange(band_a.YSize):
                for pixel_a, pixel_b in zip(a_array[row_index], b_array[row_index]):
                    numpy.testing.assert_almost_equal(pixel_a, pixel_b,
                        msg='%s != %s ... Failed at row %s' %
                        (pixel_a, pixel_b, row_index))
