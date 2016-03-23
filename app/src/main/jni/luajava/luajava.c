
/******************************************************************************
* $Id$
* Copyright (C) 2003-2007 Kepler Project.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

/***************************************************************************
*
* $ED
*    This module is the implementation of luajava's dynamic library.
*    In this module lua's functions are exported to be used in java by jni,
*    and also the functions that will be used and exported to lua so that
*    Java Objects' functions can be called.
*
*****************************************************************************/


#include <stdio.h>
#include <stdlib.h>
#include "luajava.h"
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
//#include <android/log.h>


/* Constant that is used to index the JNI Environment */
#define LUAJAVAJNIENVTAG      "__JNIEnv"
/* Defines whether the metatable is of a java Object */
#define LUAJAVAOBJECTIND      "__IsJavaObject"
/* Defines the lua State Index Property Name */
#define LUAJAVASTATEINDEX     "LuaJavaStateIndex"
/* Index metamethod name */
#define LUAINDEXMETAMETHODTAG "__index"
/* New index metamethod name */
#define LUANEWINDEXMETAMETHODTAG "__newindex"
/* Garbage collector metamethod name */
#define LUAGCMETAMETHODTAG    "__gc"
/* Call metamethod name */
#define LUACALLMETAMETHODTAG  "__call"
/* Constant that defines where in the metatable should I place the function name */
#define LUAJAVAOBJFUNCCALLED  "__FunctionCalled"

static JavaVM *jvm = NULL;

static jclass    throwable_class      = NULL;
static jmethodID get_message_method   = NULL;
static jclass    java_function_class  = NULL;
static jmethodID java_function_method = NULL;
static jclass    luajava_api_class    = NULL;
static jclass    java_lang_class      = NULL;
static jmethodID luajava_api_java_new = NULL;
static jmethodID luajava_api_object_index = NULL;
static jmethodID luajava_api_check_field = NULL;
static jfieldID  CPtr_peer_ID = NULL;
static jmethodID luajava_api_class_index = NULL;
static jmethodID luajava_api_object_new_index = NULL;
static jmethodID luajava_api_array_index = NULL;
static jmethodID luajava_api_array_new_index = NULL;
static jmethodID luajava_api_java_new_instance = NULL;
static jmethodID luajava_api_call_java_method = NULL;


/***************************************************************************
*
* $FC Function objectIndex
*
* $ED Description
*    Function to be called by the metamethod __index of the java object
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int objectIndex( lua_State * L );


/***************************************************************************
*
* $FC Function objectIndexReturn
*
* $ED Description
*    Function returned by the metamethod __index of a java Object. It is
*    the actual function that is going to call the java method.
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int objectIndexReturn( lua_State * L );


/***************************************************************************
*
* $FC Function objectNewIndex
*
* $ED Description
*    Function to be called by the metamethod __newindex of the java object
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int objectNewIndex( lua_State * L );


/***************************************************************************
*
* $FC Function classIndex
*
* $ED Description
*    Function to be called by the metamethod __index of the java class
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int classIndex( lua_State * L );


/***************************************************************************
*
* $FC Function arrayIndex
*
* $ED Description
*    Function to be called by the metamethod __index of a java array
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int arrayIndex( lua_State * L );


/***************************************************************************
*
* $FC Function arrayNewIndex
*
* $ED Description
*    Function to be called by the metamethod __newindex of a java array
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int arrayNewIndex( lua_State * L );


/***************************************************************************
*
* $FC Function GC
*
* $ED Description
*    Function to be called by the metamethod __gc of the java object
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int gc( lua_State * L );


/***************************************************************************
*
* $FC Function javaBindClass
*
* $ED Description
*    Implementation of lua function luajava.BindClass
*
* $EP Function Parameters
*    $P L - lua State
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int javaBindClass( lua_State * L );

/***************************************************************************
*
* $FC Function createProxy
*
* $ED Description
*    Implementation of lua function luajava.createProxy.
*    Transform a lua table into a java class that implements a list
*  of interfaces
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int createProxy( lua_State * L );

/***************************************************************************
*
* $FC Function javaNew
*
* $ED Description
*    Implementation of lua function luajava.new
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int javaNew( lua_State * L );


/***************************************************************************
*
* $FC Function javaNewInstance
*
* $ED Description
*    Implementation of lua function luajava.newInstance
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int javaNewInstance( lua_State * L );


/***************************************************************************
*
* $FC Function javaLoadLib
*
* $ED Description
*    Implementation of lua function luajava.loadLib
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int javaLoadLib( lua_State * L );


/***************************************************************************
*
* $FC pushJavaObject
*
* $ED Description
*    Function to create a lua proxy to a java object
*
* $EP Function Parameters
*    $P L - lua State
*    $P javaObject - Java Object to be pushed on the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int pushJavaObject( lua_State * L , jobject javaObject, JNIEnv * env );


/***************************************************************************
*
* $FC pushJavaArray
*
* $ED Description
*    Function to create a lua proxy to a java array
*
* $EP Function Parameters
*    $P L - lua State
*    $P javaObject - Java array to be pushed on the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int pushJavaArray( lua_State * L , jobject javaObject, JNIEnv * env );


/***************************************************************************
*
* $FC pushJavaClass
*
* $ED Description
*    Function to create a lua proxy to a java class
*
* $EP Function Parameters
*    $P L - lua State
*    $P javaObject - Java Class to be pushed on the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function
*
*$. **********************************************************************/

   static int pushJavaClass( lua_State * L , jobject javaObject );


/***************************************************************************
*
* $FC isJavaObject
*
* $ED Description
*    Returns 1 is given index represents a java object
*
* $EP Function Parameters
*    $P L - lua State
*    $P idx - index on the stack
*
* $FV Returned Value
*    int - Boolean.
*
*$. **********************************************************************/

   static int isJavaObject( lua_State * L , int idx );


/***************************************************************************
*
* $FC getStateFromCPtr
*
* $ED Description
*    Returns the lua_State from the CPtr Java Object
*
* $EP Function Parameters
*    $P L - lua State
*    $P cptr - CPtr object
*
* $FV Returned Value
*    int - Number of values to be returned by the function.
*
*$. **********************************************************************/

   static lua_State * getStateFromCPtr( JNIEnv * env , jobject cptr );


/***************************************************************************
*
* $FC luaJavaFunctionCall
*
* $ED Description
*    function called by metamethod __call of instances of JavaFunctionWrapper
*
* $EP Function Parameters
*    $P L - lua State
*    $P Stack - Parameters will be received by the stack
*
* $FV Returned Value
*    int - Number of values to be returned by the function.
*
*$. **********************************************************************/

   static int luaJavaFunctionCall( lua_State * L );


/***************************************************************************
*
* $FC pushJNIEnv
*
* $ED Description
*    function that pushes the jni environment into the lua state
*
* $EP Function Parameters
*    $P env - java environment
*    $P L - lua State
*
* $FV Returned Value
*    void
*
*$. **********************************************************************/

   static void pushJNIEnv( JNIEnv * env , lua_State * L );


   /***************************************************************************
*
* $FC getEnvFromState
*
* $ED Description
*    auxiliary function to get the JNIEnv from the lua state
*
* $EP Function Parameters
*    $P L - lua State
*
* $FV Returned Value
*    JNIEnv * - JNI environment
*
*$. **********************************************************************/

   static JNIEnv * getEnvFromState( lua_State * L );


/********************* Implementations ***************************/

void handleException(lua_State * L, JNIEnv * javaEnv, jstring str)
{
   jthrowable exp = ( *javaEnv )->ExceptionOccurred( javaEnv );

   /* Handles exception */
   if ( exp != NULL )
   {
      jobject jstr;
      const char * cStr;

      ( *javaEnv )->ExceptionClear( javaEnv );
      jstr = ( *javaEnv )->CallObjectMethod( javaEnv , exp , get_message_method );

      if (str != NULL)
        ( *javaEnv )->DeleteLocalRef( javaEnv , str );

      if ( jstr == NULL )
      {
         jmethodID methodId;

         methodId = ( *javaEnv )->GetMethodID( javaEnv , throwable_class , "toString" , "()Ljava/lang/String;" );
         jstr = ( *javaEnv )->CallObjectMethod( javaEnv , exp , methodId );
      }

      cStr = ( *javaEnv )->GetStringUTFChars( javaEnv , jstr , NULL );

      lua_pushstring( L , cStr );

      ( *javaEnv )->ReleaseStringUTFChars( javaEnv , jstr, cStr );

      lua_error( L );
   }

   if (str != NULL)
      ( *javaEnv )->DeleteLocalRef( javaEnv , str );

}

    /* Gets the luaState index */
static int getLuaStateIndex ( lua_State * L )
{
   int stateIndex;
   lua_pushstring( L , LUAJAVASTATEINDEX );
   lua_rawget( L , LUA_REGISTRYINDEX );

   if ( !lua_isnumber( L , -1 ) )
   {
      luaL_error( L , "Impossible to identify luaState id."  );
   }

   stateIndex = lua_tonumber( L , -1 );
   lua_pop( L , 1 );

   return stateIndex;
}

static jobject pushReference(lua_State *L, JNIEnv *javaEnv, jobject javaObject)
{
    jobject * userData , globalRef;
    globalRef = ( *javaEnv )->NewGlobalRef( javaEnv , javaObject );
    userData = ( jobject * ) lua_newuserdata( L , sizeof( jobject ) );
    *userData = globalRef;
    return globalRef;
}

#define lua_jobject(L,idx) *(jobject*) lua_touserdata(L,idx)

/***************************************************************************
*
*  Function: objectIndex
*  ****/

int objectIndex( lua_State * L )
{
   lua_Number stateIndex;
   int isField = 1;
   const char * key;
   jmethodID method;
   jint checkField;
   jobject obj;
   jstring str;
   JNIEnv * javaEnv;

   if ( !isJavaObject( L , 1 ) )
   {
      luaL_error( L, "Not a valid Java Object."  );
   }

   if ( !lua_isstring( L , 2 ) )  // wuz -1 ??
   {
      luaL_error( L , "Invalid object index. Must be string." );
   }

   key = lua_tostring( L , 2 );
   obj = lua_jobject( L , 1 );

   lua_getmetatable(L, 1);
   lua_getfield(L,-1,key);
   if (lua_isnumber(L,-1)) {
       isField = lua_tointeger(L,-1);
       if (isField == 0) {
       //    luaL_error(L,"field '%s' does not exist",key);
       }
   }
   lua_pop(L,1);

   javaEnv = getEnvFromState( L );
   stateIndex = lua_tointeger(L, lua_upvalueindex(2));

   // first see if it's a field, not a method. Can skip this if we know that it isn't a field
   if (isField > 0) {
        str = ( *javaEnv )->NewStringUTF( javaEnv , key );
        checkField = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
            luajava_api_check_field ,(jint)stateIndex , obj , str );
        handleException (L,javaEnv,str);

       if (isField == 1) { // first time we've met this chap...
           lua_getmetatable(L, 1);
           // it is definitely a field, or _not_ a field
           lua_pushinteger(L,checkField != 0 ? 2 : 0);
           lua_setfield(L,-2,key);
           lua_pop(L,1);
       }

       if ( checkField != 0 )
       {
          return checkField;
       }
   }

   lua_pushlightuserdata(L, javaEnv);
   lua_pushinteger(L, stateIndex);
   lua_pushstring(L , key );
   lua_pushcclosure (L, &objectIndexReturn, 3);

   return 1;
}


/***************************************************************************
*
*  Function: objectIndexReturn
*  ****/

int objectIndexReturn( lua_State * L )
{
   lua_Number stateIndex;
   jobject obj;
   jmethodID method;
   const char * methodName;
   jint ret;
   jstring str;
   JNIEnv * javaEnv;

   javaEnv = getEnvFromState( L );
   stateIndex = lua_tointeger(L, lua_upvalueindex(2));
   methodName = lua_tostring( L, lua_upvalueindex(3));

   /* Checks if is a valid java object */
   if ( !isJavaObject( L , 1 ) )
   {
      luaL_error( L , "Not a valid OO function call."  );
   }

   obj = lua_jobject( L , 1 );

   str = ( *javaEnv )->NewStringUTF( javaEnv , methodName );
   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_object_index, (jint)stateIndex, 1, obj , str );
   handleException (L,javaEnv,str);

   /* pushes new object into lua stack */
   return ret;
}


/***************************************************************************
*
*  Function: objectNewIndex
*  ****/

int objectNewIndex( lua_State * L  )
{
   lua_Number stateIndex;
   jobject obj;
   jmethodID method;
   const char * fieldName;
   jstring str;
   jint ret;
   JNIEnv * javaEnv;

   stateIndex = getLuaStateIndex( L );
   javaEnv = getEnvFromState( L );

   if ( !isJavaObject( L , 1 ) )
   {
      luaL_error( L , "Not a valid java class."  );
   }

   /* Gets the field Name */

   if ( !lua_isstring( L , 2 ) )
   {
      luaL_error( L , "Not a valid field call.");
   }

   fieldName = lua_tostring( L , 2 );

   /* Gets the object reference */
   obj = lua_jobject( L , 1 );
   str = ( *javaEnv )->NewStringUTF( javaEnv , fieldName );
   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class , luajava_api_object_new_index,
                                    (jint)stateIndex , obj , str );
   handleException (L,javaEnv,str);

   return ret;
}


/***************************************************************************
*
*  Function: classIndex
*  ****/

int classIndex( lua_State * L )
{
   lua_Number stateIndex;
   jobject obj;
   jmethodID method;
   const char * fieldName;
   jstring str;
   jint ret;
   JNIEnv * javaEnv;


   javaEnv = getEnvFromState( L );
   stateIndex = getLuaStateIndex( L );

   if ( !isJavaObject( L , 1 ) )
   {
      lua_pushstring( L , "Not a valid java class." );
      lua_error( L );
   }

   /* Gets the field Name */

   if ( !lua_isstring( L , 2 ) )
   {
      lua_pushstring( L , "Not a valid field call." );
      lua_error( L );
   }

   fieldName = lua_tostring( L , 2 );

   /* Gets the object reference */
   obj = lua_jobject( L , 1 );

   str = ( *javaEnv )->NewStringUTF( javaEnv , fieldName );

   /* Return 1 for field, 2 for method or 0 for error */
   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_class_index, (jint)stateIndex , obj , str );

   handleException (L,javaEnv,str);

   if ( ret == 0 )  {
      luaL_error( L, "Name is not a static field or function."  );
   }

   if ( ret == 2 ) {
      lua_pushlightuserdata(L, javaEnv);
      lua_pushinteger(L, stateIndex);
      lua_pushstring( L , fieldName );
      lua_pushcclosure ( L, &objectIndexReturn, 3);
      return 1;
   }

   return ret;
}


/***************************************************************************
*
*  Function: arrayIndex
*  ****/

int arrayIndex( lua_State * L )
{
   lua_Number stateIndex;
   int key;
   jmethodID method;
   jint ret;
   jobject obj;
   JNIEnv * javaEnv;

   javaEnv = getEnvFromState( L );
   stateIndex = getLuaStateIndex( L );

   if ( !isJavaObject( L , 1 ) )
   {
      lua_pushstring( L , "Not a valid Java Object." );
      lua_error( L );
   }

	/* Can index as number or string */
   if ( !lua_isnumber( L , 2 ) && !lua_isstring( L , 2 ) )
   {
      lua_pushstring( L , "Invalid object index. Must be integer or string." );
      lua_error( L );
   }

	/* Important! If the index is not a number, behave as normal Java object */
	if ( !lua_isnumber( L , 2) )
	{
        lua_getmetatable( L, 1 );
        lua_getfield( L, -1, "__fallback");
        lua_pushvalue(L,1);
        lua_pushvalue(L,2);
        lua_call(L,2,1);
		return 1;
	}

	// Array index
   key = lua_tointeger( L , 2 );

   obj = lua_jobject( L , 1 );


   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
            luajava_api_array_index ,(jint)stateIndex , obj , (jint)key );

   handleException (L,javaEnv,NULL);

   return ret;
}


/***************************************************************************
*
*  Function: arrayNewIndex
*  ****/

int arrayNewIndex( lua_State * L )
{
   lua_Number stateIndex;
   jobject obj;
   jmethodID method;
   lua_Integer key;
   jint ret;
   JNIEnv * javaEnv;

   javaEnv = getEnvFromState( L );
   stateIndex = getLuaStateIndex( L );

   if ( !isJavaObject( L , 1 ) )
   {
      lua_pushstring( L , "Not a valid java class." );
      lua_error( L );
   }

   /* Gets the field Name */

   if ( !lua_isnumber( L , 2 ) )
   {
      lua_pushstring( L , "Not a valid array index." );
      lua_error( L );
   }

   key = lua_tointeger( L , 2 );

   /* Gets the object reference */
   obj = lua_jobject( L , 1 );


   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_array_new_index, (jint)stateIndex , obj , (jint)key );

   handleException (L,javaEnv,NULL);

   return ret;
}


/***************************************************************************
*
*  Function: gc
*  ****/

int gc( lua_State * L )
{
   jobject obj;
   JNIEnv * javaEnv;

   if ( !isJavaObject( L , 1 ) )
   {
      return 0;
   }

   obj = lua_jobject( L , 1 );

   /* Gets the JNI Environment */
   javaEnv = getEnvFromState( L );

   ( *javaEnv )->DeleteGlobalRef( javaEnv , obj );

   return 0;
}


/***************************************************************************
*
*  Function: javaBindClass
*  ****/

int javaBindClass( lua_State * L )
{
   int top, stateIndex;
   jmethodID method;
   const char * className;
   jstring javaClassName;
   jobject classInstance;
   JNIEnv * javaEnv;

    javaEnv = getEnvFromState( L );
    stateIndex = lua_tonumber( L , lua_upvalueindex(2));

   top = lua_gettop( L );

   if ( top != 1 )
   {
      luaL_error( L , "Error. Function javaBindClass received %d arguments, expected 1." , top );
   }

   /* get the string parameter */
   if ( !lua_isstring( L , 1 ) )
   {
      lua_pushstring( L , "Invalid parameter type. String expected." );
      lua_error( L );
   }

   className = lua_tostring( L , 1 );

   method = ( *javaEnv )->GetStaticMethodID( javaEnv , java_lang_class , "forName" ,
                                             "(Ljava/lang/String;)Ljava/lang/Class;" );

   javaClassName = ( *javaEnv )->NewStringUTF( javaEnv , className );

   classInstance = ( *javaEnv )->CallStaticObjectMethod( javaEnv , java_lang_class ,
                                                         method , javaClassName );

   handleException (L,javaEnv,javaClassName);

   /* pushes new object into lua stack */

   return pushJavaClass( L , classInstance );
}


/***************************************************************************
*
*  Function: luajava.createProxy
*  ****/
int createProxy( lua_State * L )
{
  jint ret;
  lua_Number stateIndex;
  const char * impl;
  jmethodID method;
  jstring str;
  JNIEnv * javaEnv;

  javaEnv = getEnvFromState( L );
  stateIndex = lua_tonumber( L , lua_upvalueindex(2));

  if ( lua_gettop( L ) != 2 )
  {
    luaL_error( L, "Error. Function createProxy expects 2 arguments."  );
  }

  //* stateIndex = getLuaStateIndex( L );

   if ( !lua_isstring( L , 1 ) || !lua_istable( L , 2 ) )
   {
      luaL_error( L , "Invalid Argument types. Expected (string, table)."  );
   }

   method = ( *javaEnv )->GetStaticMethodID( javaEnv , luajava_api_class , "createProxyObject" ,
                                             "(ILjava/lang/String;)I" );

   impl = lua_tostring( L , 1 );
   str = ( *javaEnv )->NewStringUTF( javaEnv , impl );
   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class , method, (jint)stateIndex , str );
   handleException (L,javaEnv,str);

   return ret;
}

static int callMethod( lua_State *L )
{
    JNIEnv * javaEnv = getEnvFromState(L);
    lua_Number stateIndex = lua_tonumber( L , lua_upvalueindex(2));
    jobject method = lua_jobject(L, lua_upvalueindex(1));
    jobject obj = lua_jobject(L,1);

    jint ret = (*javaEnv)->CallStaticIntMethod(javaEnv,luajava_api_class,
        luajava_api_call_java_method, (jint)stateIndex, obj, method);
    handleException (L,javaEnv,NULL);

    return ret;
}

static int method( lua_State *L )
{
    jstring str;
    JNIEnv * javaEnv = getEnvFromState(L);
    lua_Number stateIndex = lua_tonumber( L , lua_upvalueindex(2));

    // name argument must be popped...
    jobject obj = lua_jobject(L,1);
    const char *name = lua_tostring(L,2);
    lua_remove(L,2);

    str = ( *javaEnv )->NewStringUTF( javaEnv , name );
    // if called like this, pushes actual method on Lua stack!
    ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_object_index, (jint)stateIndex, 0, obj , str );
    handleException (L,javaEnv,str);


    // push method caller
   //lua_pushlightuserdata( L , javaEnv);
   lua_pushinteger( L, stateIndex);
   lua_pushcclosure( L , &callMethod, 2 );

    return 1;
}

/***************************************************************************
*
*  Function: javaNew
*  ****/

int javaNew( lua_State * L )
{
   int top;
   jint ret;
   jobject classInstance ;
   lua_Number stateIndex;
   JNIEnv * javaEnv;

   javaEnv = getEnvFromState( L );
   stateIndex = lua_tonumber( L , lua_upvalueindex(2));

   top = lua_gettop( L );

   if ( top == 0 )
   {
      luaL_error( L , "Error. Invalid number of parameters."  );
   }

   /* Gets the java Class reference */
   if ( !isJavaObject( L , 1 ) )  {
      luaL_error( L , "Argument not a valid Java Class."  );
   }

   classInstance = lua_jobject( L , 1 );

   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_java_new , (jint)stateIndex , classInstance );

   handleException (L,javaEnv,NULL);

  return ret;
}


/***************************************************************************
*
*  Function: javaNewInstance
*  ****/

int javaNewInstance( lua_State * L )
{
   jint ret;
   jmethodID method;
   const char * className;
   jstring javaClassName;
   lua_Number stateIndex;
   JNIEnv * javaEnv;

    javaEnv = getEnvFromState( L );
    //* javaEnv = (JNIEnv *) lua_touserdata( L , lua_upvalueindex(1));
    stateIndex = lua_tonumber( L , lua_upvalueindex(2));

   /* get the string parameter */
   if ( !lua_isstring( L , 1 ) )  {
      luaL_error( L , "Invalid parameter type. String expected as first parameter."  );
   }

   className = lua_tostring( L , 1 );

   javaClassName = ( *javaEnv )->NewStringUTF( javaEnv , className );
   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class ,
        luajava_api_java_new_instance, (jint)stateIndex , javaClassName );
   handleException (L,javaEnv,javaClassName);

   return ret;
}


/***************************************************************************
*
*  Function: javaLoadLib
*  ****/

int javaLoadLib( lua_State * L )
{
   jint ret;
   int top;
   const char * className, * methodName;
   lua_Number stateIndex;
   jmethodID method;
   jstring javaClassName , javaMethodName;
   JNIEnv * javaEnv;

   javaEnv = getEnvFromState( L );
   stateIndex = lua_tonumber( L , lua_upvalueindex(2));

   top = lua_gettop( L );

   if ( top != 2 )  {
      luaL_error( L, "Error. Invalid number of parameters."  );
   }

   if ( !lua_isstring( L , 1 ) || !lua_isstring( L , 2 ) ) {
      luaL_error( L , "Invalid parameter. Strings expected."  );
   }

   className  = lua_tostring( L , 1 );
   methodName = lua_tostring( L , 2 );

   method = ( *javaEnv )->GetStaticMethodID( javaEnv , luajava_api_class , "javaLoadLib" ,
                                             "(ILjava/lang/String;Ljava/lang/String;)I" );

   javaClassName  = ( *javaEnv )->NewStringUTF( javaEnv , className );
   javaMethodName = ( *javaEnv )->NewStringUTF( javaEnv , methodName );

   ret = ( *javaEnv )->CallStaticIntMethod( javaEnv , luajava_api_class , method, (jint)stateIndex ,
                                            javaClassName , javaMethodName );

   handleException (L,javaEnv,javaClassName);

   ( *javaEnv )->DeleteLocalRef( javaEnv , javaMethodName );

   return ret;
}

static void register_function(lua_State *L, const char *name, lua_CFunction fn, JNIEnv * env, int stateId)
{
  lua_pushstring( L , name );
  lua_pushlightuserdata( L , env);
  lua_pushinteger( L, stateId);
  lua_pushcclosure( L , fn, 2 );
  lua_rawset( L , -3 );
}

/***************************************************************************
*
*  Function: pushJavaClass
*  ****/

int pushJavaClass( lua_State * L , jobject javaObject )
{

   JNIEnv * javaEnv = getEnvFromState( L );

   jobject globalRef = pushReference(L,javaEnv,javaObject);

   /* Setup metatable for this object*/
   lua_newtable( L );

   /* pushes the __index metamethod */
   lua_pushstring( L , LUAINDEXMETAMETHODTAG );
   lua_pushcfunction( L , &classIndex );
   lua_rawset( L , -3 );

   /* pushes the __newindex metamethod */
   lua_pushstring( L , LUANEWINDEXMETAMETHODTAG );
   lua_pushcfunction( L , &objectNewIndex );
   lua_rawset( L , -3 );

   /* pushes the __gc metamethod */
   lua_pushstring( L , LUAGCMETAMETHODTAG );
   lua_pushcfunction( L , &gc );
   lua_rawset( L , -3 );

   /* Is Java Object boolean */
   lua_pushstring( L , LUAJAVAOBJECTIND );
   lua_pushboolean( L , 1 );
   lua_rawset( L , -3 );

   if ( lua_setmetatable( L , -2 ) == 0 )
   {
    	( *javaEnv )->DeleteGlobalRef( javaEnv , globalRef );
        luaL_error( L , "Cannot create proxy to java class."  );
   }

   return 1;
}


/***************************************************************************
*
*  Function: pushJavaObject
*  ****/

int pushJavaObject( lua_State * L , jobject javaObject, JNIEnv * javaEnv )
{
   jobject globalRef;
   int stateId;

   stateId = getLuaStateIndex( L );

   globalRef = pushReference(L,javaEnv,javaObject);

   /* Creates metatable */
   lua_newtable( L );

   /* pushes the __index metamethod */
   lua_pushstring( L , LUAINDEXMETAMETHODTAG );
   lua_pushlightuserdata( L , javaEnv);
   lua_pushinteger( L, stateId);
   lua_pushcclosure( L , &objectIndex, 2 );
   lua_rawset( L , -3 );

   /* pushes the __newindex metamethod */
   lua_pushstring( L , LUANEWINDEXMETAMETHODTAG );
   lua_pushcfunction( L , &objectNewIndex );
   lua_rawset( L , -3 );

   /* pushes the __gc metamethod */
   lua_pushstring( L , LUAGCMETAMETHODTAG );
   lua_pushcfunction( L , &gc );
   lua_rawset( L , -3 );

   /* Is Java Object boolean */
   lua_pushstring( L , LUAJAVAOBJECTIND );
   lua_pushboolean( L , 1 );
   lua_rawset( L , -3 );

   if ( lua_setmetatable( L , -2 ) == 0 )
   {
      ( *javaEnv )->DeleteGlobalRef( javaEnv , globalRef );
      luaL_error( L, "Cannot create proxy to java object." );
   }

   return 1;
}


/***************************************************************************
*
*  Function: pushJavaArray
*  ****/

int pushJavaArray( lua_State * L , jobject javaObject, JNIEnv * javaEnv )
{
   jobject globalRef;
   int stateId = getLuaStateIndex( L );

   globalRef = pushReference(L,javaEnv,javaObject);

   /* Creates metatable */
   lua_newtable( L );

   /* pushes the __index metamethod */
   lua_pushstring( L , LUAINDEXMETAMETHODTAG );
   lua_pushcfunction( L , &arrayIndex );
   lua_rawset( L , -3 );

   /* pushes the __fallback metamethod (used for non-integer keys*/
   lua_pushstring( L , "__fallback" );
   lua_pushlightuserdata( L , javaEnv);
   lua_pushinteger( L, stateId);
   lua_pushcclosure( L , &objectIndex, 2 );
   lua_rawset( L , -3 );

   /* pushes the __newindex metamethod */
   lua_pushstring( L , LUANEWINDEXMETAMETHODTAG );
   lua_pushcfunction( L , &arrayNewIndex );
   lua_rawset( L , -3 );

   /* pushes the __gc metamethod */
   lua_pushstring( L , LUAGCMETAMETHODTAG );
   lua_pushcfunction( L , &gc );
   lua_rawset( L , -3 );

   /* Is Java Object boolean */
   lua_pushstring( L , LUAJAVAOBJECTIND );
   lua_pushboolean( L , 1 );
   lua_rawset( L , -3 );

   if ( lua_setmetatable( L , -2 ) == 0 )
   {
      ( *javaEnv )->DeleteGlobalRef( javaEnv , globalRef );
      luaL_error( L , "Cannot create proxy to java object.");
   }
   return 1;
}


/***************************************************************************
*
*  Function: isJavaObject
*  ****/

int isJavaObject( lua_State * L , int idx )
{
   if ( !lua_isuserdata( L , idx ) )
      return 0;

   if ( lua_getmetatable( L , idx ) == 0 )
      return 0;

   lua_pushstring( L , LUAJAVAOBJECTIND );
   lua_rawget( L , -2 );

   if (lua_isnil( L, -1 ))
   {
      lua_pop( L , 2 );
      return 0;
   }
   lua_pop( L , 2 );
   return 1;
}


/***************************************************************************
*
*  Function: getStateFromCPtr
*  ****/

lua_State * getStateFromCPtr( JNIEnv * env , jobject cptr )
{
   lua_State * L;

   jbyte * peer = ( jbyte * ) ( *env )->GetLongField( env , cptr , CPtr_peer_ID );

   L = ( lua_State * ) peer;

  //* pushJNIEnv( env ,  L );

   return L;
}


/***************************************************************************
*
*  Function: luaJavaFunctionCall
*  ****/

int luaJavaFunctionCall( lua_State * L )
{
   jobject obj;
   int ret;
   JNIEnv * javaEnv;

   if ( !isJavaObject( L , 1 ) )
   {
      lua_pushstring( L , "Not a java Function." );
      lua_error( L );
   }

   obj = lua_jobject( L , 1 );

   /* Gets the JNI Environment */
   javaEnv = getEnvFromState( L );

   /* the Object must be an instance of the JavaFunction class */
   if ( ( *javaEnv )->IsInstanceOf( javaEnv , obj , java_function_class ) ==
        JNI_FALSE )  {
      luaL_error(L , "Called Java object is not a JavaFunction\n");
   }

   ret = ( *javaEnv )->CallIntMethod( javaEnv , obj , java_function_method );

   handleException (L,javaEnv,NULL);

   return ret;
}


/***************************************************************************
*
*  Function: luaJavaFunctionCall
*  ****/

JNIEnv * getEnvFromState( lua_State * L )
{
   JNIEnv *env;
   jint rs = (*jvm)->AttachCurrentThread(jvm, &env, NULL);
   if ( rs != JNI_OK )  {
      luaL_error( L  , "Invalid JNI Environment." );
   }
   return env;
}

/***************************************************************************
*
*  Function: pushJNIEnv
*  ****/

void pushJNIEnv( JNIEnv * env , lua_State * L )
{
   JNIEnv ** udEnv;

   lua_pushstring( L , LUAJAVAJNIENVTAG );
   lua_rawget( L , LUA_REGISTRYINDEX );

   if ( !lua_isnil( L , -1 ) )
   {
      udEnv = ( JNIEnv ** ) lua_touserdata( L , -1 );
      *udEnv = env;
      lua_pop( L , 1 );
   }
   else
   {
      lua_pop( L , 1 );
      udEnv = ( JNIEnv ** ) lua_newuserdata( L , sizeof( JNIEnv * ) );
      *udEnv = env;

      lua_pushstring( L , LUAJAVAJNIENVTAG );
      lua_insert( L , -2 );
      lua_rawset( L , LUA_REGISTRYINDEX );
   }
}

/*
** Assumes the table is on top of the stack.
*/
static void set_info (lua_State *L) {
	lua_pushliteral (L, "_COPYRIGHT");
	lua_pushliteral (L, "Copyright (C) 2003-2007 Kepler Project");
	lua_settable (L, -3);
	lua_pushliteral (L, "_DESCRIPTION");
	lua_pushliteral (L, "LuaJava is a script tool for Java");
	lua_settable (L, -3);
	lua_pushliteral (L, "_NAME");
	lua_pushliteral (L, "LuaJava");
	lua_settable (L, -3);
	lua_pushliteral (L, "_VERSION");
	lua_pushliteral (L, "1.1");
	lua_settable (L, -3);
}

/**************************** JNI FUNCTIONS ****************************/

/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

static check_error(int res, const char *msg)
{
    if ( res )
    {
      fprintf( stderr , msg );
      exit( 1 );
    }

}

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState_luajava_1open
  ( JNIEnv * env , jobject jobj , jobject cptr , jint stateId )
{
  lua_State* L;
  JNIEnv **udEnv;
  jclass tempClass;

  if ( CPtr_peer_ID == NULL) {
    tempClass = ( *env )->FindClass( env, "org/keplerproject/luajava/CPtr");
    CPtr_peer_ID = ( *env )->GetFieldID( env , tempClass , "peer" , "J" );
    // cache the JVM
    jint rs = (*env)->GetJavaVM(env, &jvm);
   // assert (rs == JNI_OK);

  }

  L = getStateFromCPtr( env , cptr );

  lua_pushstring( L , LUAJAVASTATEINDEX );
  lua_pushnumber( L , (lua_Number)stateId );
  lua_settable( L , LUA_REGISTRYINDEX );

  lua_newtable( L );
  lua_setglobal( L , "luajava" );
  lua_getglobal( L , "luajava" );
  set_info( L);

  register_function(L,"bindClass",&javaBindClass,env,stateId);
  register_function(L,"new",&javaNew,env,stateId);
  register_function(L,"newInstance",&javaNewInstance,env,stateId);
  register_function(L,"loadLib",&javaLoadLib,env,stateId);
  register_function(L,"createProxy",&createProxy,env,stateId);
  register_function(L,"method",&method,env,stateId);

  lua_pop( L , 1 );

  if ( luajava_api_class == NULL )
  {

    tempClass = ( *env )->FindClass( env , "org/keplerproject/luajava/LuaJavaAPI" );
    check_error ( tempClass == NULL, "Could not find LuaJavaAPI class\n" );

    luajava_api_class = ( *env )->NewGlobalRef( env , tempClass );
    check_error ( luajava_api_class == NULL,"Could not bind to LuaJavaAPI class\n" );

    tempClass = ( *env )->FindClass( env , "org/keplerproject/luajava/JavaFunction" );
    check_error ( tempClass == NULL, "Could not find JavaFunction interface\n" );

    java_function_class = ( *env )->NewGlobalRef( env , tempClass );
    check_error ( java_function_class == NULL,"Could not bind to JavaFunction interface\n" );

    java_function_method = ( *env )->GetMethodID( env , java_function_class , "execute" , "()I");
    check_error ( !java_function_method, "Could not find <execute> method in JavaFunction\n" );

    tempClass = ( *env )->FindClass( env , "java/lang/Throwable" );
    check_error ( tempClass == NULL,  "Error. Couldn't bind java class java.lang.Throwable\n" );

    throwable_class = ( *env )->NewGlobalRef( env , tempClass );
    get_message_method = ( *env )->GetMethodID( env , throwable_class , "getMessage" ,
                                                "()Ljava/lang/String;" );
    check_error ( get_message_method == NULL, "Could not find <getMessage> method in java.lang.Throwable\n");

    luajava_api_java_new = ( *env )->GetStaticMethodID( env , luajava_api_class , "javaNew" ,
                                             "(ILjava/lang/Class;)I" );
    luajava_api_check_field = ( *env )->GetStaticMethodID( env , luajava_api_class , "checkField" ,
                                             "(ILjava/lang/Object;Ljava/lang/String;)I" );


    luajava_api_object_index = ( *env )->GetStaticMethodID( env , luajava_api_class , "objectIndex" ,
                                             "(IILjava/lang/Object;Ljava/lang/String;)I" );

    luajava_api_object_new_index = ( *env )->GetStaticMethodID( env , luajava_api_class , "objectNewIndex" ,
                                             "(ILjava/lang/Object;Ljava/lang/String;)I" );

    luajava_api_class_index = ( *env )->GetStaticMethodID( env , luajava_api_class , "classIndex" ,
                                             "(ILjava/lang/Class;Ljava/lang/String;)I" );

    luajava_api_array_index = ( *env )->GetStaticMethodID( env , luajava_api_class , "arrayIndex" ,
                                             "(ILjava/lang/Object;I)I" );

    luajava_api_call_java_method = ( *env )->GetStaticMethodID( env , luajava_api_class , "callJavaMethod" ,
                                             "(ILjava/lang/Object;Ljava/lang/Object;)I" );

   luajava_api_array_new_index = ( *env )->GetStaticMethodID( env , luajava_api_class , "arrayNewIndex" ,
                                             "(ILjava/lang/Object;I)I" );

   luajava_api_java_new_instance = ( *env )->GetStaticMethodID( env , luajava_api_class , "javaNewInstance" ,
                                             "(ILjava/lang/String;)I" );

    tempClass = ( *env )->FindClass( env , "java/lang/Class" );
    java_lang_class = ( *env )->NewGlobalRef( env , tempClass );

  }

  pushJNIEnv( env , L );
}

/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT jobject JNICALL Java_org_keplerproject_luajava_LuaState__1getObjectFromUserdata
  (JNIEnv * env , jobject jobj , jobject cptr , jint index )
{
   /* Get luastate */
   lua_State * L = getStateFromCPtr( env , cptr );
   jobject   obj;

   if ( !isJavaObject( L , index ) )
   {
      ( *env )->ThrowNew( env , ( *env )->FindClass( env , "java/lang/Exception" ) ,
                          "Index is not a java object" );
      return NULL;
   }

   obj = lua_jobject( L , index );

   return obj;
}


/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT jboolean JNICALL Java_org_keplerproject_luajava_LuaState__1isObject
  (JNIEnv * env , jobject jobj , jobject cptr , jint index )
{
   /* Get luastate */
   lua_State * L = getStateFromCPtr( env , cptr );

   return (isJavaObject( L , index ) ? JNI_TRUE : JNI_FALSE );
}


/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushJavaObject
  (JNIEnv * env , jobject jobj , jobject cptr , jobject obj )
{
   /* Get luastate */
   lua_State* L = getStateFromCPtr( env , cptr );

   pushJavaObject( L , obj, env );
}


/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushJavaArray
  (JNIEnv * env , jobject jobj , jobject cptr , jobject obj )
{
   /* Get luastate */
    lua_State* L = getStateFromCPtr( env , cptr );

	pushJavaArray( L , obj, env );
}


/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushJavaFunction
  (JNIEnv * env , jobject jobj , jobject cptr , jobject obj )
{
   /* Get luastate */
   lua_State* L = getStateFromCPtr( env , cptr );

   jobject globalRef = pushReference(L, env , obj );

   /* Creates metatable */
   lua_newtable( L );

   /* pushes the __index metamethod */
   lua_pushstring( L , LUACALLMETAMETHODTAG );
   lua_pushcfunction( L , &luaJavaFunctionCall );
   lua_rawset( L , -3 );

   /* pusher the __gc metamethod */
   lua_pushstring( L , LUAGCMETAMETHODTAG );
   lua_pushcfunction( L , &gc );
   lua_rawset( L , -3 );

   lua_pushstring( L , LUAJAVAOBJECTIND );
   lua_pushboolean( L , 1 );
   lua_rawset( L , -3 );

   if ( lua_setmetatable( L , -2 ) == 0 )
   {
      ( *env )->ThrowNew( env , ( *env )->FindClass( env , "org/keplerproject/luajava/LuaException" ) ,
                          "Index is not a java object" );
   }
}


/************************************************************************
*   JNI Called function
*      LuaJava API Function
************************************************************************/

JNIEXPORT jboolean JNICALL Java_org_keplerproject_luajava_LuaState__1isJavaFunction
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   /* Get luastate */
   lua_State* L = getStateFromCPtr( env , cptr );
   jobject obj;

   if ( !isJavaObject( L , idx ) )
   {
      return JNI_FALSE;
   }

   obj = lua_jobject( L , idx );

   return ( *env )->IsInstanceOf( env , obj , java_function_class );

}


/*********************** LUA API FUNCTIONS ******************************/

/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jobject JNICALL Java_org_keplerproject_luajava_LuaState__1open
  (JNIEnv * env , jobject jobj)
{
   lua_State * L = lua_open();

   jobject obj;
   jclass tempClass;

   tempClass = ( *env )->FindClass( env , "org/keplerproject/luajava/CPtr" );

   obj = ( *env )->AllocObject( env , tempClass );
   if ( obj )
   {
      ( *env )->SetLongField( env , obj , ( *env )->GetFieldID( env , tempClass , "peer", "J" ) , ( jlong ) L );
   }
   return obj;

}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openBase
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_base( L );
   lua_pushcfunction( L , luaopen_base );
   lua_pushstring( L , "" );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openTable
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_table( L );
   lua_pushcfunction( L , luaopen_table );
   lua_pushstring( L , LUA_TABLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openIo
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_io( L );
   lua_pushcfunction( L , luaopen_io );
   lua_pushstring( L , LUA_IOLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openOs
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_os( L );
   lua_pushcfunction( L , luaopen_os );
   lua_pushstring( L , LUA_OSLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openString
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_string( L );
   lua_pushcfunction( L , luaopen_string );
   lua_pushstring( L , LUA_STRLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openMath
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_math( L );
   lua_pushcfunction( L , luaopen_math );
   lua_pushstring( L , LUA_MATHLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openDebug
  (JNIEnv * env, jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_debug( L );
   lua_pushcfunction( L , luaopen_debug );
   lua_pushstring( L , LUA_DBLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openPackage
  (JNIEnv * env, jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   //luaopen_package( L );
   lua_pushcfunction( L , luaopen_package );
   lua_pushstring( L , LUA_LOADLIBNAME );
   lua_call(L , 1 , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1openLibs
  (JNIEnv * env, jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_openlibs( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1close
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_close( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jobject JNICALL Java_org_keplerproject_luajava_LuaState__1newthread
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );
   lua_State * newThread;

   jobject obj;
   jclass tempClass;

   newThread = lua_newthread( L );

   tempClass = ( *env )->FindClass( env , "org/keplerproject/luajava/CPtr" );
   obj = ( *env )->AllocObject( env , tempClass );
   if ( obj )
   {
      ( *env )->SetLongField( env , obj , ( *env )->GetFieldID( env , tempClass ,
                                                        "peer" , "J" ), ( jlong ) L );
   }

   return obj;

}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1getTop
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_gettop( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1setTop
  (JNIEnv * env , jobject jobj , jobject cptr , jint top)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_settop( L , ( int ) top );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushValue
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pushvalue( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1remove
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_remove( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1insert
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_insert( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1replace
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_replace( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1checkStack
  (JNIEnv * env , jobject jobj , jobject cptr , jint sz)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_checkstack( L , ( int ) sz );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1xmove
  (JNIEnv * env , jobject jobj , jobject from , jobject to , jint n)
{
   lua_State * fr = getStateFromCPtr( env , from );
   lua_State * t  = getStateFromCPtr( env , to );

   lua_xmove( fr , t , ( int ) n );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isNumber
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isnumber( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isString
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isstring( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isFunction
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isfunction( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isCFunction
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_iscfunction( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isUserdata
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isuserdata( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_istable( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isBoolean
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isboolean( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isNil
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isnil( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isNone
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isnone( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1isNoneOrNil
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_isnoneornil( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1type
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_type( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1typeName
  (JNIEnv * env , jobject jobj , jobject cptr , jint tp)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * name = lua_typename( L , tp );

   return ( *env )->NewStringUTF( env , name );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1equal
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx1 , jint idx2)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_equal( L , idx1 , idx2 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1rawequal
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx1 , jint idx2)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_rawequal( L , idx1 , idx2 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1lessthan
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx1 , jint idx2)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_lessthan( L , idx1 ,idx2 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jdouble JNICALL Java_org_keplerproject_luajava_LuaState__1toNumber
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jdouble ) lua_tonumber( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1toInteger
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_tointeger( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1toBoolean
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_toboolean( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1toString
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * str = lua_tostring( L , idx );

   return ( *env )->NewStringUTF( env , str );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1strlen
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_strlen( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1objlen
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_objlen( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jobject JNICALL Java_org_keplerproject_luajava_LuaState__1toThread
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L , * thr;

   jobject obj;
   jclass tempClass;

   L = getStateFromCPtr( env , cptr );

   thr = lua_tothread( L , ( int ) idx );

   tempClass = ( *env )->FindClass( env , "org/keplerproject/luajava/CPtr" );

   obj = ( *env )->AllocObject( env , tempClass );
   if ( obj )
   {
      ( *env )->SetLongField( env , obj , ( *env )->GetFieldID( env , tempClass , "peer", "J" ) , ( jlong ) thr );
   }
   return obj;

}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushNil
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pushnil( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushNumber
  (JNIEnv * env , jobject jobj , jobject cptr , jdouble number)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pushnumber( L , ( lua_Number ) number );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushInteger
  (JNIEnv * env , jobject jobj , jobject cptr , jint number)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pushinteger( L, ( lua_Integer ) number );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushString__Lorg_keplerproject_luajava_CPtr_2Ljava_lang_String_2
  (JNIEnv * env , jobject jobj , jobject cptr , jstring str)
{
   lua_State * L = getStateFromCPtr( env , cptr );
   const char * uniStr;

   uniStr =  ( *env )->GetStringUTFChars( env , str , NULL );

   if ( uniStr == NULL )
      return;

   lua_pushstring( L , uniStr );

   ( *env )->ReleaseStringUTFChars( env , str , uniStr );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushString__Lorg_keplerproject_luajava_CPtr_2_3BI
  (JNIEnv * env , jobject jobj , jobject cptr , jbyteArray bytes , jint n)
{
   lua_State * L = getStateFromCPtr( env , cptr );
   char * cBytes;

   cBytes = ( char * ) ( *env )->GetByteArrayElements( env , bytes, NULL );

   lua_pushlstring( L , cBytes , n );

   ( *env )->ReleaseByteArrayElements( env , bytes , cBytes , 0 );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pushBoolean
  (JNIEnv * env , jobject jobj , jobject cptr , jint jbool)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pushboolean( L , ( int ) jbool );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1getTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_gettable( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1getField
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx , jstring k)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * uniStr;
   uniStr =  ( *env )->GetStringUTFChars( env , k , NULL );

   lua_getfield( L , ( int ) idx , uniStr );

   ( *env )->ReleaseStringUTFChars( env , k , uniStr );
}

/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1rawGet
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_rawget( L , (int)idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1rawGetI
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx, jint n)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_rawgeti( L , idx , n );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1createTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint narr , jint nrec)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_createtable( L , ( int ) narr , ( int ) nrec );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1newTable
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_newtable( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1getMetaTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return lua_getmetatable( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1getFEnv
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_getfenv( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1setTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_settable( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1setField
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx , jstring k)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * uniStr;
   uniStr =  ( *env )->GetStringUTFChars( env , k , NULL );

   lua_setfield( L , ( int ) idx , uniStr );

   ( *env )->ReleaseStringUTFChars( env , k , uniStr );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1rawSet
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_rawset( L , (int)idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1rawSetI
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx, jint n)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_rawseti( L , idx , n );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1setMetaTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return lua_setmetatable( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1setFEnv
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return lua_setfenv( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1call
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArgs , jint nResults)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_call( L , nArgs , nResults );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1pcall
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArgs , jint nResults , jint errFunc)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_pcall( L , nArgs , nResults , errFunc );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1yield
  (JNIEnv * env , jobject jobj , jobject cptr , jint nResults)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_yield( L , nResults );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1resume
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArgs)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_resume( L , nArgs );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1status
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_status( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1gc
  (JNIEnv * env , jobject jobj , jobject cptr , jint what , jint data)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_gc( L , what , data );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1getGcCount
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_getgccount( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1next
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_next( L , idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1error
  (JNIEnv * env , jobject jobj , jobject cptr)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) lua_error( L );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1concat
  (JNIEnv * env , jobject jobj , jobject cptr , jint n)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_concat( L , n );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1pop
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   lua_pop( L , ( int ) idx );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1setGlobal
  (JNIEnv * env , jobject jobj , jobject cptr , jstring name)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * str = ( *env )->GetStringUTFChars( env , name, NULL );

   lua_setglobal( L , str );

   ( *env )->ReleaseStringUTFChars( env , name , str );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1getGlobal
  (JNIEnv * env , jobject jobj , jobject cptr , jstring name)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * str = ( *env )->GetStringUTFChars( env , name, NULL );

   lua_getglobal( L , str );

   ( *env )->ReleaseStringUTFChars( env , name , str );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LdoFile
  (JNIEnv * env , jobject jobj , jobject cptr , jstring fileName)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * file = ( *env )->GetStringUTFChars( env , fileName, NULL );

   int ret;

   ret = luaL_dofile( L , file );

   ( *env )->ReleaseStringUTFChars( env , fileName , file );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LdoString
  (JNIEnv * env , jobject jobj , jobject cptr , jstring str)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   const char * utfStr = ( * env )->GetStringUTFChars( env , str , NULL );

   int ret;

   ret = luaL_dostring( L , utfStr );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LgetMetaField
  (JNIEnv * env , jobject jobj , jobject cptr , jint obj , jstring e)
{
   lua_State * L    = getStateFromCPtr( env , cptr );
   const char * str = ( *env )->GetStringUTFChars( env , e , NULL );
   int ret;

   ret = luaL_getmetafield( L , ( int ) obj , str );

   ( *env )->ReleaseStringUTFChars( env , e , str );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LcallMeta
  (JNIEnv * env , jobject jobj , jobject cptr , jint obj , jstring e)
{
   lua_State * L    = getStateFromCPtr( env , cptr );
   const char * str = ( *env )->GetStringUTFChars( env , e , NULL );
   int ret;

   ret = luaL_callmeta( L , ( int ) obj, str );

   ( *env )->ReleaseStringUTFChars( env , e , str );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1Ltyperror
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArg , jstring tName)
{
   lua_State * L     = getStateFromCPtr( env , cptr );
   const char * name = ( *env )->GetStringUTFChars( env , tName , NULL );
   int ret;

   ret = luaL_typerror( L , ( int ) nArg , name );

   ( *env )->ReleaseStringUTFChars( env , tName , name );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LargError
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg , jstring extraMsg)
{
   lua_State * L    = getStateFromCPtr( env , cptr );
   const char * msg = ( *env )->GetStringUTFChars( env , extraMsg , NULL );
   int ret;

   ret = luaL_argerror( L , ( int ) numArg , msg );

   ( *env )->ReleaseStringUTFChars( env , extraMsg , msg );

   return ( jint ) ret;;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckString
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg)
{
   lua_State * L = getStateFromCPtr( env , cptr );
   const char * res;

   res = luaL_checkstring( L , ( int ) numArg );

   return ( *env )->NewStringUTF( env , res );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1LoptString
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg , jstring def)
{
   lua_State * L  = getStateFromCPtr( env , cptr );
   const char * d = ( *env )->GetStringUTFChars( env , def , NULL );
   const char * res;
   jstring ret;

   res = luaL_optstring( L , ( int ) numArg , d );

   ret = ( *env )->NewStringUTF( env , res );

   ( *env )->ReleaseStringUTFChars( env , def , d );

   return ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jdouble JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckNumber
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jdouble ) luaL_checknumber( L , ( int ) numArg );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jdouble JNICALL Java_org_keplerproject_luajava_LuaState__1LoptNumber
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg , jdouble def)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jdouble ) luaL_optnumber( L , ( int ) numArg , ( lua_Number ) def );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckInteger
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) luaL_checkinteger( L , ( int ) numArg );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LoptInteger
  (JNIEnv * env , jobject jobj , jobject cptr , jint numArg , jint def)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) luaL_optinteger( L , ( int ) numArg , ( lua_Integer ) def );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckStack
  (JNIEnv * env , jobject jobj , jobject cptr , jint sz , jstring msg)
{
   lua_State * L  = getStateFromCPtr( env , cptr );
   const char * m = ( *env )->GetStringUTFChars( env , msg , NULL );

   luaL_checkstack( L , ( int ) sz , m );

   ( *env )->ReleaseStringUTFChars( env , msg , m );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckType
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArg , jint t)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_checktype( L , ( int ) nArg , ( int ) t );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LcheckAny
  (JNIEnv * env , jobject jobj , jobject cptr , jint nArg)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_checkany( L , ( int ) nArg );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LnewMetatable
  (JNIEnv * env , jobject jobj , jobject cptr , jstring tName)
{
   lua_State * L     = getStateFromCPtr( env , cptr );
   const char * name = ( *env )->GetStringUTFChars( env , tName , NULL );
   int ret;

   ret = luaL_newmetatable( L , name );

   ( *env )->ReleaseStringUTFChars( env , tName , name );

   return ( jint ) ret;;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LgetMetatable
  (JNIEnv * env , jobject jobj , jobject cptr , jstring tName)
{
   lua_State * L     = getStateFromCPtr( env , cptr );
   const char * name = ( *env )->GetStringUTFChars( env , tName , NULL );

   luaL_getmetatable( L , name );

   ( *env )->ReleaseStringUTFChars( env , tName , name );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1Lwhere
  (JNIEnv * env , jobject jobj , jobject cptr , jint lvl)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_where( L , ( int ) lvl );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1Lref
  (JNIEnv * env , jobject jobj , jobject cptr , jint t)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) luaL_ref( L , ( int ) t );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LunRef
  (JNIEnv * env , jobject jobj , jobject cptr , jint t , jint ref)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_unref( L , ( int ) t , ( int ) ref );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LgetN
  (JNIEnv * env , jobject jobj , jobject cptr , jint t)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   return ( jint ) luaL_getn( L , ( int ) t );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT void JNICALL Java_org_keplerproject_luajava_LuaState__1LsetN
  (JNIEnv * env , jobject jobj , jobject cptr , jint t , jint n)
{
   lua_State * L = getStateFromCPtr( env , cptr );

   luaL_setn( L , ( int ) t , ( int ) n );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LloadFile
  (JNIEnv * env , jobject jobj , jobject cptr , jstring fileName)
{
   lua_State * L   = getStateFromCPtr( env , cptr );
   const char * fn = ( *env )->GetStringUTFChars( env , fileName , NULL );
   int ret;

   ret = luaL_loadfile( L , fn );

   ( *env )->ReleaseStringUTFChars( env , fileName , fn );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LloadBuffer
  (JNIEnv * env , jobject jobj , jobject cptr , jbyteArray buff , jlong sz , jstring n)
{
   lua_State * L = getStateFromCPtr( env , cptr );
   jbyte * cBuff = ( *env )->GetByteArrayElements( env , buff, NULL );
   const char * name = ( * env )->GetStringUTFChars( env , n , NULL );
   int ret;

   ret = luaL_loadbuffer( L , ( const char * ) cBuff, ( int ) sz, name );

   ( *env )->ReleaseStringUTFChars( env , n , name );

   ( *env )->ReleaseByteArrayElements( env , buff , cBuff , 0 );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jint JNICALL Java_org_keplerproject_luajava_LuaState__1LloadString
  (JNIEnv * env , jobject jobj , jobject cptr , jstring str)
{
   lua_State * L   = getStateFromCPtr( env , cptr );
   const char * fn = ( *env )->GetStringUTFChars( env , str , NULL );
   int ret;

   ret = luaL_loadstring( L , fn );

   ( *env )->ReleaseStringUTFChars( env , str , fn );

   return ( jint ) ret;
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1Lgsub
  (JNIEnv * env , jobject jobj , jobject cptr , jstring s , jstring p , jstring r)
{
   lua_State * L   = getStateFromCPtr( env , cptr );
   const char * utS = ( *env )->GetStringUTFChars( env , s , NULL );
   const char * utP = ( *env )->GetStringUTFChars( env , p , NULL );
   const char * utR = ( *env )->GetStringUTFChars( env , r , NULL );

   const char * sub = luaL_gsub( L , utS , utP , utR );

   ( *env )->ReleaseStringUTFChars( env , s , utS );
   ( *env )->ReleaseStringUTFChars( env , p , utP );
   ( *env )->ReleaseStringUTFChars( env , r , utR );

   return ( *env )->NewStringUTF( env , sub );
}


/************************************************************************
*   JNI Called function
*      Lua Exported Function
************************************************************************/

JNIEXPORT jstring JNICALL Java_org_keplerproject_luajava_LuaState__1LfindTable
  (JNIEnv * env , jobject jobj , jobject cptr , jint idx , jstring fname , jint szhint)
{
   lua_State * L   = getStateFromCPtr( env , cptr );
   const char * name = ( *env )->GetStringUTFChars( env , fname , NULL );

   const char * sub = luaL_findtable( L , ( int ) idx , name , ( int ) szhint );

   ( *env )->ReleaseStringUTFChars( env , fname , name );

   return ( *env )->NewStringUTF( env , sub );
}
