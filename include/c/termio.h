#ifdef __cplusplus
extern "C" {
#endif

extern void WrChar(const char c);
extern void WrString(const PChar s);

extern void WrByteDec(const byte v);
extern void WrWordDec(const word v);
extern void WrDwordDec(const ulong v);
extern void WrByteHex(const byte v);
extern void WrWordHex(const word v);
extern void WrDwordHex(const ulong v);

#ifdef __cplusplus
}
#endif