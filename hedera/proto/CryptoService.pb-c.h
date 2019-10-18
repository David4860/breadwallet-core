/* Generated by the protocol buffer compiler.  DO NOT EDIT! */
/* Generated from: CryptoService.proto */

#ifndef PROTOBUF_C_CryptoService_2eproto__INCLUDED
#define PROTOBUF_C_CryptoService_2eproto__INCLUDED

#include "protobuf-c.h"

PROTOBUF_C__BEGIN_DECLS

#if PROTOBUF_C_VERSION_NUMBER < 1003000
# error This file was generated by a newer version of protoc-c which is incompatible with your libprotobuf-c headers. Please update your headers.
#elif 1003002 < PROTOBUF_C_MIN_COMPILER_VERSION
# error This file was generated by an older version of protoc-c which is incompatible with your libprotobuf-c headers. Please regenerate this file with a newer version of protoc-c.
#endif

#include "Query.pb-c.h"
#include "Response.pb-c.h"
#include "TransactionResponse.pb-c.h"
#include "Transaction.pb-c.h"



/* --- enums --- */


/* --- messages --- */

/* --- per-message closures --- */


/* --- services --- */

typedef struct _Proto__CryptoService_Service Proto__CryptoService_Service;
struct _Proto__CryptoService_Service
{
  ProtobufCService base;
  void (*create_account)(Proto__CryptoService_Service *service,
                         const Proto__Transaction *input,
                         Proto__TransactionResponse_Closure closure,
                         void *closure_data);
  void (*update_account)(Proto__CryptoService_Service *service,
                         const Proto__Transaction *input,
                         Proto__TransactionResponse_Closure closure,
                         void *closure_data);
  void (*crypto_transfer)(Proto__CryptoService_Service *service,
                          const Proto__Transaction *input,
                          Proto__TransactionResponse_Closure closure,
                          void *closure_data);
  void (*crypto_delete)(Proto__CryptoService_Service *service,
                        const Proto__Transaction *input,
                        Proto__TransactionResponse_Closure closure,
                        void *closure_data);
  void (*add_claim)(Proto__CryptoService_Service *service,
                    const Proto__Transaction *input,
                    Proto__TransactionResponse_Closure closure,
                    void *closure_data);
  void (*delete_claim)(Proto__CryptoService_Service *service,
                       const Proto__Transaction *input,
                       Proto__TransactionResponse_Closure closure,
                       void *closure_data);
  void (*get_claim)(Proto__CryptoService_Service *service,
                    const Proto__Query *input,
                    Proto__Response_Closure closure,
                    void *closure_data);
  void (*get_account_records)(Proto__CryptoService_Service *service,
                              const Proto__Query *input,
                              Proto__Response_Closure closure,
                              void *closure_data);
  void (*crypto_get_balance)(Proto__CryptoService_Service *service,
                             const Proto__Query *input,
                             Proto__Response_Closure closure,
                             void *closure_data);
  void (*get_account_info)(Proto__CryptoService_Service *service,
                           const Proto__Query *input,
                           Proto__Response_Closure closure,
                           void *closure_data);
  void (*get_transaction_receipts)(Proto__CryptoService_Service *service,
                                   const Proto__Query *input,
                                   Proto__Response_Closure closure,
                                   void *closure_data);
  void (*get_fast_transaction_record)(Proto__CryptoService_Service *service,
                                      const Proto__Query *input,
                                      Proto__Response_Closure closure,
                                      void *closure_data);
  void (*get_tx_record_by_tx_id)(Proto__CryptoService_Service *service,
                                 const Proto__Query *input,
                                 Proto__Response_Closure closure,
                                 void *closure_data);
  void (*get_stakers_by_account_id)(Proto__CryptoService_Service *service,
                                    const Proto__Query *input,
                                    Proto__Response_Closure closure,
                                    void *closure_data);
};
typedef void (*Proto__CryptoService_ServiceDestroy)(Proto__CryptoService_Service *);
void proto__crypto_service__init (Proto__CryptoService_Service *service,
                                  Proto__CryptoService_ServiceDestroy destroy);
#define PROTO__CRYPTO_SERVICE__BASE_INIT \
    { &proto__crypto_service__descriptor, protobuf_c_service_invoke_internal, NULL }
#define PROTO__CRYPTO_SERVICE__INIT(function_prefix__) \
    { PROTO__CRYPTO_SERVICE__BASE_INIT,\
      function_prefix__ ## create_account,\
      function_prefix__ ## update_account,\
      function_prefix__ ## crypto_transfer,\
      function_prefix__ ## crypto_delete,\
      function_prefix__ ## add_claim,\
      function_prefix__ ## delete_claim,\
      function_prefix__ ## get_claim,\
      function_prefix__ ## get_account_records,\
      function_prefix__ ## crypto_get_balance,\
      function_prefix__ ## get_account_info,\
      function_prefix__ ## get_transaction_receipts,\
      function_prefix__ ## get_fast_transaction_record,\
      function_prefix__ ## get_tx_record_by_tx_id,\
      function_prefix__ ## get_stakers_by_account_id  }
void proto__crypto_service__create_account(ProtobufCService *service,
                                           const Proto__Transaction *input,
                                           Proto__TransactionResponse_Closure closure,
                                           void *closure_data);
void proto__crypto_service__update_account(ProtobufCService *service,
                                           const Proto__Transaction *input,
                                           Proto__TransactionResponse_Closure closure,
                                           void *closure_data);
void proto__crypto_service__crypto_transfer(ProtobufCService *service,
                                            const Proto__Transaction *input,
                                            Proto__TransactionResponse_Closure closure,
                                            void *closure_data);
void proto__crypto_service__crypto_delete(ProtobufCService *service,
                                          const Proto__Transaction *input,
                                          Proto__TransactionResponse_Closure closure,
                                          void *closure_data);
void proto__crypto_service__add_claim(ProtobufCService *service,
                                      const Proto__Transaction *input,
                                      Proto__TransactionResponse_Closure closure,
                                      void *closure_data);
void proto__crypto_service__delete_claim(ProtobufCService *service,
                                         const Proto__Transaction *input,
                                         Proto__TransactionResponse_Closure closure,
                                         void *closure_data);
void proto__crypto_service__get_claim(ProtobufCService *service,
                                      const Proto__Query *input,
                                      Proto__Response_Closure closure,
                                      void *closure_data);
void proto__crypto_service__get_account_records(ProtobufCService *service,
                                                const Proto__Query *input,
                                                Proto__Response_Closure closure,
                                                void *closure_data);
void proto__crypto_service__crypto_get_balance(ProtobufCService *service,
                                               const Proto__Query *input,
                                               Proto__Response_Closure closure,
                                               void *closure_data);
void proto__crypto_service__get_account_info(ProtobufCService *service,
                                             const Proto__Query *input,
                                             Proto__Response_Closure closure,
                                             void *closure_data);
void proto__crypto_service__get_transaction_receipts(ProtobufCService *service,
                                                     const Proto__Query *input,
                                                     Proto__Response_Closure closure,
                                                     void *closure_data);
void proto__crypto_service__get_fast_transaction_record(ProtobufCService *service,
                                                        const Proto__Query *input,
                                                        Proto__Response_Closure closure,
                                                        void *closure_data);
void proto__crypto_service__get_tx_record_by_tx_id(ProtobufCService *service,
                                                   const Proto__Query *input,
                                                   Proto__Response_Closure closure,
                                                   void *closure_data);
void proto__crypto_service__get_stakers_by_account_id(ProtobufCService *service,
                                                      const Proto__Query *input,
                                                      Proto__Response_Closure closure,
                                                      void *closure_data);

/* --- descriptors --- */

extern const ProtobufCServiceDescriptor proto__crypto_service__descriptor;

PROTOBUF_C__END_DECLS


#endif  /* PROTOBUF_C_CryptoService_2eproto__INCLUDED */