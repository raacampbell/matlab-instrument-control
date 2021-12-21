#include "stdafx.h"

// [] = DCAM4StopCapture(cameraHandle)
// Stop capturing started by DCAM4StartCapture().
void mexFunction(int nlhs, mxArray* plhs[], int	nrhs, const	mxArray* prhs[])
{
	unsigned long* mHandle;
	HDCAM	       handle;
	DCAMERR        error;

	// Grab the inputs from MATLAB.
	mHandle = (unsigned long*)mxGetUint64s(prhs[0]);
	handle = (HDCAM)mHandle[0];

	// Call the dcam function.
	error = dcamcap_stop(handle);
	if (failed(error))
	{
		mexPrintf("Error = 0x%08lX\ndcamcap_stop() failed.\n", error);
	}

	return;
}