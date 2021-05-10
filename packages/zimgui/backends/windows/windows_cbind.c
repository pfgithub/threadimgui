#ifndef UNICODE
#define UNICODE
#endif 

#include <windows.h>

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

int startCv2(const char* win_name, int width, int height, void* data_ptr) {
	HINSTANCE hInstance = GetModuleHandle(NULL);
	
    // Register the window class.
    const wchar_t CLASS_NAME[]  = L"main window";
    
    WNDCLASS wc = { };

    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;

    RegisterClass(&wc);

    // Create the window.

    HWND hwnd = CreateWindowEx(
        0,                              // Optional window styles.
        CLASS_NAME,                     // Window class
        L"Window title",    // Window text
        WS_OVERLAPPEDWINDOW,            // Window style

        // Size and position
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,

        NULL,       // Parent window    
        NULL,       // Menu
        hInstance,  // Instance handle
        data_ptr        // Additional application data (void*)
    );

    if (hwnd == NULL)
    {
        return 0;
    }

    ShowWindow(hwnd, SW_SHOW);

    // Run the message loop.

    MSG msg = { };
    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}

void* GetAppState(HWND hwnd) {
	LONG_PTR ptr = GetWindowLongPtr(hwnd, GWLP_USERDATA);
	void* ptrRes = (void*)ptr;
	return ptrRes;
}

typedef struct {
    HWND hwnd;
    /// only defined if this is a render frame
    HDC hdc;
} WindowData;

void zig_on_resize(WindowData* wd, void* ptr, int width, int height);
void zig_on_paint(WindowData* wd, void* state_ptr);

void c_repaint_window(WindowData* wd) {
    InvalidateRect(wd->hwnd, /*rect: */NULL, /*erase: */FALSE);
}
void c_rounded_rect(WindowData* wd, unsigned long color_rgb, int left, int top, int right, int bottom, int rx, int ry) {
    HBRUSH brush = CreateSolidBrush(color_rgb);
    SelectObject(wd->hdc, brush);
    DeleteObject(brush);
    SelectObject(wd->hdc, GetStockObject(NULL_PEN));
    RoundRect(wd->hdc, left, top, right, bottom, rx, ry);
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	void* statePtr;
	if(uMsg == WM_CREATE) {
		CREATESTRUCT *pCreate = (CREATESTRUCT*)lParam;
		statePtr = (void*)pCreate->lpCreateParams;
		SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)statePtr);
	}else{
		statePtr = GetAppState(hwnd);
	}

    WindowData wd = {.hwnd = hwnd}; // don't save this across frames
	
    switch (uMsg)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_ERASEBKGND:
        return 0;
    case WM_PAINT:
        {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hwnd, &ps);

            RECT clientRect;
            GetClientRect(hwnd, &clientRect);
            int width = clientRect.right - clientRect.left;
            int height = clientRect.bottom - clientRect.top;

            HDC hDC = GetDC(hwnd);
            HDC memoryDC = CreateCompatibleDC(hDC);
            HBITMAP memoryBitmap = CreateCompatibleBitmap(hDC, width, height);
            SelectObject(memoryDC, memoryBitmap);

            FillRect(memoryDC, &ps.rcPaint, (HBRUSH) (COLOR_WINDOW+1));
            wd.hdc = memoryDC;
            zig_on_paint(&wd, statePtr);

            BitBlt(hdc, 0, 0, width, height, memoryDC, 0, 0, SRCCOPY);
            ReleaseDC(hwnd, hDC);

            EndPaint(hwnd, &ps);
        }
        return 0;
	case WM_SIZE: {
		int width = LOWORD(lParam);
		int height = HIWORD(lParam);
		zig_on_resize(&wd, statePtr, width, height);
	}; break;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}