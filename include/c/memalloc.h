#ifdef __cplusplus
extern "C" {
#endif

extern pointer AllocBlock(size_t Sz);
extern void FreeBlock(pointer Ptr);

#ifdef __cplusplus
}
#endif