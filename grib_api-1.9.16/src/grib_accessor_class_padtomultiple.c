/**
* Copyright 2005-2007 ECMWF
* 
* Licensed under the GNU Lesser General Public License which
* incorporates the terms and conditions of version 3 of the GNU
* General Public License.
* See LICENSE and gpl-3.0.txt for details.
*/

/**************************************
 *  Enrico Fucile
 **************************************/


#include "grib_api_internal.h"
/*
   This is used by make_class.pl

   START_CLASS_DEF
   CLASS      = accessor
   SUPER      = grib_accessor_class_padding
   IMPLEMENTS = init;preferred_size
   MEMBERS=grib_expression* begin
   MEMBERS=grib_expression* multiple
   END_CLASS_DEF

 */

/* START_CLASS_IMP */

/*

Don't edit anything between START_CLASS_IMP and END_CLASS_IMP
Instead edit values between START_CLASS_DEF and END_CLASS_DEF
or edit "accessor.class" and rerun ./make_class.pl

*/

static void init(grib_accessor*,const long, grib_arguments* );
static void init_class(grib_accessor_class*);
static size_t preferred_size(grib_accessor*,int);

typedef struct grib_accessor_padtomultiple {
    grib_accessor          att;
/* Members defined in gen */
/* Members defined in bytes */
/* Members defined in padding */
/* Members defined in padtomultiple */
	grib_expression* begin;
	grib_expression* multiple;
} grib_accessor_padtomultiple;

extern grib_accessor_class* grib_accessor_class_padding;

static grib_accessor_class _grib_accessor_class_padtomultiple = {
    &grib_accessor_class_padding,                      /* super                     */
    "padtomultiple",                      /* name                      */
    sizeof(grib_accessor_padtomultiple),  /* size                      */
    0,                           /* inited */
    &init_class,                 /* init_class */
    &init,                       /* init                      */
    0,                  /* post_init                      */
    0,                    /* free mem                       */
    0,                       /* describes himself         */
    0,                /* get length of section     */
    0,                /* get number of values      */
    0,                 /* get number of bytes      */
    0,                /* get offset to bytes           */
    0,            /* get native type               */
    0,                /* get sub_section                */
    0,               /* grib_pack procedures long      */
    0,               /* grib_pack procedures long      */
    0,                  /* grib_pack procedures long      */
    0,                /* grib_unpack procedures long    */
    0,                /* grib_pack procedures double    */
    0,              /* grib_unpack procedures double  */
    0,                /* grib_pack procedures string    */
    0,              /* grib_unpack procedures string  */
    0,                 /* grib_pack procedures bytes     */
    0,               /* grib_unpack procedures bytes   */
    0,            /* pack_expression */
    0,              /* notify_change   */
    0,                /* update_size   */
    &preferred_size,            /* preferred_size   */
    0,                    /* resize   */
    0,      /* nearest_smaller_value */
    0,                       /* next accessor    */
    0,                    /* compare vs. another accessor   */
    0,     /* unpack only ith value          */
    0,     /* unpack a subarray         */
    0,             		/* clear          */
};


grib_accessor_class* grib_accessor_class_padtomultiple = &_grib_accessor_class_padtomultiple;


static void init_class(grib_accessor_class* c)
{
	c->dump	=	(*(c->super))->dump;
	c->next_offset	=	(*(c->super))->next_offset;
	c->value_count	=	(*(c->super))->value_count;
	c->byte_count	=	(*(c->super))->byte_count;
	c->byte_offset	=	(*(c->super))->byte_offset;
	c->get_native_type	=	(*(c->super))->get_native_type;
	c->sub_section	=	(*(c->super))->sub_section;
	c->pack_missing	=	(*(c->super))->pack_missing;
	c->is_missing	=	(*(c->super))->is_missing;
	c->pack_long	=	(*(c->super))->pack_long;
	c->unpack_long	=	(*(c->super))->unpack_long;
	c->pack_double	=	(*(c->super))->pack_double;
	c->unpack_double	=	(*(c->super))->unpack_double;
	c->pack_string	=	(*(c->super))->pack_string;
	c->unpack_string	=	(*(c->super))->unpack_string;
	c->pack_bytes	=	(*(c->super))->pack_bytes;
	c->unpack_bytes	=	(*(c->super))->unpack_bytes;
	c->pack_expression	=	(*(c->super))->pack_expression;
	c->notify_change	=	(*(c->super))->notify_change;
	c->update_size	=	(*(c->super))->update_size;
	c->resize	=	(*(c->super))->resize;
	c->nearest_smaller_value	=	(*(c->super))->nearest_smaller_value;
	c->next	=	(*(c->super))->next;
	c->compare	=	(*(c->super))->compare;
	c->unpack_double_element	=	(*(c->super))->unpack_double_element;
	c->unpack_double_subarray	=	(*(c->super))->unpack_double_subarray;
	c->clear	=	(*(c->super))->clear;
}

/* END_CLASS_IMP */

static size_t preferred_size(grib_accessor* a,int from_handle)
{
	grib_accessor_padtomultiple* self = (grib_accessor_padtomultiple*)a;
	long padding=0;
	long begin = 0;
	long multiple = 0;

	grib_expression_evaluate_long(a->parent->h,self->begin,&begin);
	grib_expression_evaluate_long(a->parent->h,self->multiple,&multiple);

	padding = a->offset - begin;
	padding = ((padding + multiple - 1)/multiple)*multiple - padding;

	return padding == 0 ? multiple : padding;

}

static void init(grib_accessor* a, const long len, grib_arguments *arg )
{
	grib_accessor_padtomultiple* self = (grib_accessor_padtomultiple*)a;

	self->begin    =  grib_arguments_get_expression(a->parent->h, arg,0);
	self->multiple = grib_arguments_get_expression(a->parent->h, arg,1);
	a->length         = preferred_size(a,1);
}
