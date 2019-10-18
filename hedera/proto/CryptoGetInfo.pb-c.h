/* Generated by the protocol buffer compiler.  DO NOT EDIT! */
/* Generated from: CryptoGetInfo.proto */

#ifndef PROTOBUF_C_CryptoGetInfo_2eproto__INCLUDED
#define PROTOBUF_C_CryptoGetInfo_2eproto__INCLUDED

#include "protobuf-c.h"

PROTOBUF_C__BEGIN_DECLS

#if PROTOBUF_C_VERSION_NUMBER < 1003000
# error This file was generated by a newer version of protoc-c which is incompatible with your libprotobuf-c headers. Please update your headers.
#elif 1003002 < PROTOBUF_C_MIN_COMPILER_VERSION
# error This file was generated by an older version of protoc-c which is incompatible with your libprotobuf-c headers. Please regenerate this file with a newer version of protoc-c.
#endif

#include "Timestamp.pb-c.h"
#include "Duration.pb-c.h"
#include "BasicTypes.pb-c.h"
#include "QueryHeader.pb-c.h"
#include "ResponseHeader.pb-c.h"
#include "CryptoAddClaim.pb-c.h"

typedef struct _Proto__CryptoGetInfoQuery Proto__CryptoGetInfoQuery;
typedef struct _Proto__CryptoGetInfoResponse Proto__CryptoGetInfoResponse;
typedef struct _Proto__CryptoGetInfoResponse__AccountInfo Proto__CryptoGetInfoResponse__AccountInfo;


/* --- enums --- */


/* --- messages --- */

/*
 * Get all the information about an account, including the balance. This does not get the list of account records. 
 */
struct  _Proto__CryptoGetInfoQuery
{
  ProtobufCMessage base;
  /*
   * Standard info sent from client to node, including the signed payment, and what kind of response is requested (cost, state proof, both, or neither).
   */
  Proto__QueryHeader *header;
  /*
   * The account ID for which information is requested
   */
  Proto__AccountID *accountid;
};
#define PROTO__CRYPTO_GET_INFO_QUERY__INIT \
 { PROTOBUF_C_MESSAGE_INIT (&proto__crypto_get_info_query__descriptor) \
    , NULL, NULL }


struct  _Proto__CryptoGetInfoResponse__AccountInfo
{
  ProtobufCMessage base;
  /*
   * The account ID for which this information applies
   */
  Proto__AccountID *accountid;
  /*
   * The Contract Account ID comprising of both the contract instance and the cryptocurrency account owned by the contract instance, in the format used by Solidity
   */
  char *contractaccountid;
  /*
   * If true, then this account has been deleted, it will disappear when it expires, and all transactions for it will fail except the transaction to extend its expiration date
   */
  protobuf_c_boolean deleted;
  /*
   * The Account ID of the account to which this is proxy staked. If proxyAccountID is null, or is an invalid account, or is an account that isn't a node, then this account is automatically proxy staked to a node chosen by the network, but without earning payments. If the proxyAccountID account refuses to accept proxy staking , or if it is not currently running a node, then it will behave as if proxyAccountID was null.
   */
  Proto__AccountID *proxyaccountid;
  /*
   * The total number of tinybars proxy staked to this account
   */
  int64_t proxyreceived;
  /*
   * The key for the account, which must sign in order to transfer out, or to modify the account in any way other than extending its expiration date.
   */
  Proto__Key *key;
  /*
   * The current balance of account in tinybars
   */
  uint64_t balance;
  /*
   * The threshold amount (in tinybars) for which an account record is created (and this account charged for them) for any send/withdraw transaction.
   */
  uint64_t generatesendrecordthreshold;
  /*
   * The threshold amount (in tinybars) for which an account record is created  (and this account charged for them) for any transaction above this amount.
   */
  uint64_t generatereceiverecordthreshold;
  /*
   * If true, no transaction can transfer to this account unless signed by this account's key
   */
  protobuf_c_boolean receiversigrequired;
  /*
   * The TimeStamp time at which this account is set to expire
   */
  Proto__Timestamp *expirationtime;
  /*
   * The duration for expiration time will extend every this many seconds. If there are insufficient funds, then it extends as long as possible. If it is empty when it expires, then it is deleted.
   */
  Proto__Duration *autorenewperiod;
  /*
   * All of the claims attached to the account (each of which is a hash along with the keys that authorized it and can delete it )
   */
  size_t n_claims;
  Proto__Claim **claims;
};
#define PROTO__CRYPTO_GET_INFO_RESPONSE__ACCOUNT_INFO__INIT \
 { PROTOBUF_C_MESSAGE_INIT (&proto__crypto_get_info_response__account_info__descriptor) \
    , NULL, (char *)protobuf_c_empty_string, 0, NULL, 0, NULL, 0, 0, 0, 0, NULL, NULL, 0,NULL }


/*
 * Response when the client sends the node CryptoGetInfoQuery 
 */
struct  _Proto__CryptoGetInfoResponse
{
  ProtobufCMessage base;
  /*
   *Standard response from node to client, including the requested fields: cost, or state proof, or both, or neither
   */
  Proto__ResponseHeader *header;
  /*
   * Info about the account (a state proof can be generated for this)
   */
  Proto__CryptoGetInfoResponse__AccountInfo *accountinfo;
};
#define PROTO__CRYPTO_GET_INFO_RESPONSE__INIT \
 { PROTOBUF_C_MESSAGE_INIT (&proto__crypto_get_info_response__descriptor) \
    , NULL, NULL }


/* Proto__CryptoGetInfoQuery methods */
void   proto__crypto_get_info_query__init
                     (Proto__CryptoGetInfoQuery         *message);
size_t proto__crypto_get_info_query__get_packed_size
                     (const Proto__CryptoGetInfoQuery   *message);
size_t proto__crypto_get_info_query__pack
                     (const Proto__CryptoGetInfoQuery   *message,
                      uint8_t             *out);
size_t proto__crypto_get_info_query__pack_to_buffer
                     (const Proto__CryptoGetInfoQuery   *message,
                      ProtobufCBuffer     *buffer);
Proto__CryptoGetInfoQuery *
       proto__crypto_get_info_query__unpack
                     (ProtobufCAllocator  *allocator,
                      size_t               len,
                      const uint8_t       *data);
void   proto__crypto_get_info_query__free_unpacked
                     (Proto__CryptoGetInfoQuery *message,
                      ProtobufCAllocator *allocator);
/* Proto__CryptoGetInfoResponse__AccountInfo methods */
void   proto__crypto_get_info_response__account_info__init
                     (Proto__CryptoGetInfoResponse__AccountInfo         *message);
/* Proto__CryptoGetInfoResponse methods */
void   proto__crypto_get_info_response__init
                     (Proto__CryptoGetInfoResponse         *message);
size_t proto__crypto_get_info_response__get_packed_size
                     (const Proto__CryptoGetInfoResponse   *message);
size_t proto__crypto_get_info_response__pack
                     (const Proto__CryptoGetInfoResponse   *message,
                      uint8_t             *out);
size_t proto__crypto_get_info_response__pack_to_buffer
                     (const Proto__CryptoGetInfoResponse   *message,
                      ProtobufCBuffer     *buffer);
Proto__CryptoGetInfoResponse *
       proto__crypto_get_info_response__unpack
                     (ProtobufCAllocator  *allocator,
                      size_t               len,
                      const uint8_t       *data);
void   proto__crypto_get_info_response__free_unpacked
                     (Proto__CryptoGetInfoResponse *message,
                      ProtobufCAllocator *allocator);
/* --- per-message closures --- */

typedef void (*Proto__CryptoGetInfoQuery_Closure)
                 (const Proto__CryptoGetInfoQuery *message,
                  void *closure_data);
typedef void (*Proto__CryptoGetInfoResponse__AccountInfo_Closure)
                 (const Proto__CryptoGetInfoResponse__AccountInfo *message,
                  void *closure_data);
typedef void (*Proto__CryptoGetInfoResponse_Closure)
                 (const Proto__CryptoGetInfoResponse *message,
                  void *closure_data);

/* --- services --- */


/* --- descriptors --- */

extern const ProtobufCMessageDescriptor proto__crypto_get_info_query__descriptor;
extern const ProtobufCMessageDescriptor proto__crypto_get_info_response__descriptor;
extern const ProtobufCMessageDescriptor proto__crypto_get_info_response__account_info__descriptor;

PROTOBUF_C__END_DECLS


#endif  /* PROTOBUF_C_CryptoGetInfo_2eproto__INCLUDED */