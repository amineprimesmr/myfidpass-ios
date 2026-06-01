package fr.myfidpass.data.dto

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive

/**
 * Tolère bool, 0/1 et chaînes — même logique que `decodeFlexibleOptionalBool` côté iOS.
 */
object FlexibleOptionalBooleanSerializer : KSerializer<Boolean?> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("FlexibleOptionalBoolean", PrimitiveKind.BOOLEAN)

    override fun deserialize(decoder: Decoder): Boolean? {
        val jsonDecoder = decoder as? JsonDecoder
        if (jsonDecoder != null) {
            val element = jsonDecoder.decodeJsonElement()
            if (element is JsonNull) return null
            val prim = element.jsonPrimitive
            prim.booleanOrNull?.let { return it }
            prim.intOrNull?.let { return it != 0 }
            val s = prim.contentOrNull?.trim()?.lowercase()
            if (s != null) {
                return s == "1" || s == "true" || s == "yes"
            }
            return null
        }
        return runCatching { decoder.decodeBoolean() }.getOrNull()
    }

    override fun serialize(encoder: Encoder, value: Boolean?) {
        if (value == null) {
            if (encoder is JsonEncoder) encoder.encodeJsonElement(JsonNull)
        } else {
            encoder.encodeBoolean(value)
        }
    }
}
