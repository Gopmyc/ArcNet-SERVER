function LIBRARY:Initialize(tJSONLib, tChaChaLib, tPolyLib, tLZWLib, tBase64Lib, sKey)
	assert(IsTable(tJSONLib) and IsFunction(tJSONLib.encode) and IsFunction(tJSONLib.decode),			"[LIB-CODEC] Invalid JSON library")
	assert(IsTable(tChaChaLib) and IsFunction(tChaChaLib.encrypt) and IsFunction(tChaChaLib.decrypt),	"[LIB-CODEC] Invalid ChaCha20 library")
	assert(IsTable(tPolyLib) and IsFunction(tPolyLib.auth),												"[LIB-CODEC] Invalid Poly1305 library")
	assert(IsTable(tLZWLib) and IsFunction(tLZWLib.compress) and IsFunction(tLZWLib.decompress),		"[LIB-CODEC] Invalid LZW library")
	assert(IsString(sKey),																				"[LIB-CODEC] Encryption key must be a string")

	return setmetatable(
		{
			JSON		= tJSONLib,
			CHACHA20	= tChaChaLib,
			POLY1305	= tPolyLib,
			LZW			= tLZWLib,
			BASE64		= tBase64Lib,
			KEY			= sKey:gsub("\\x(%x%x)", function(n) return string.char(tonumber(n, 16)) end),
		},
	{ __index	= LIBRARY })
end

function LIBRARY:IsValidData(tData)
	return IsTable(tData)
	   and IsString(tData.ID)
	   and tData.CONTENT ~= nil
	   and IsBool(tData.ENCRYPTED)
	   and IsBool(tData.COMPRESSED)
end

function LIBRARY:Compress(sContent)
	assert(IsTable(self.LZW) and IsFunction(self.LZW.compress),	"[LIB-CODEC] LZW.compress missing")
	assert(IsString(sContent),									"[LIB-CODEC] Content must be string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.LZW.compress, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to compress content, error: " .. tostring(sContent))
	end

	return sContent
end

function LIBRARY:Encrypt(sContent, sKey, sNonce)
	assert(IsString(sContent),												"[LIB-CODEC] Content must be a string")
	assert(IsString(sKey),													"[LIB-CODEC] Key must be a string")
	assert(IsString(sNonce),												"[LIB-CODEC] Nonce must be a string")
	assert(IsTable(self.CHACHA20) and IsFunction(self.CHACHA20.encrypt),	"[LIB-CODEC] CHACHA20.encrypt missing")
	assert(IsTable(self.POLY1305) and IsFunction(self.POLY1305.auth),		"[LIB-CODEC] POLY1305.auth missing")

	local bSuccess, sTag;
	local sPolyKey		= sNonce .. string.rep("\0", 20)

	bSuccess, sContent	= pcall(self.CHACHA20.encrypt, sKey, 1, sNonce, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encrypt content, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.POLY1305.auth, sContent, sPolyKey)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to generate Poly1305 tag, error: " .. tostring(sTag))
	end

	return sContent, sTag
end

function LIBRARY:Decrypt(sContent, sKey, sNonce, sTag)
	assert(IsString(sContent),												"[LIB-CODEC] Content must be a string")
	assert(IsString(sKey),													"[LIB-CODEC] Key must be a string")
	assert(IsString(sNonce),												"[LIB-CODEC] Nonce must be a string")
	assert(IsTable(self.CHACHA20) and IsFunction(self.CHACHA20.decrypt),	"[LIB-CODEC] CHACHA20.decrypt missing")
	assert(IsTable(self.POLY1305) and IsFunction(self.POLY1305.auth),		"[LIB-CODEC] POLY1305.auth missing")

	local bSuccess, sDecrypted, bValid;
	local sPolyKey	= sNonce .. string.rep("\0", 20)

	bValid			= (self.POLY1305.auth(sContent, sPolyKey) == sTag)
	if not bValid then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Invalid Poly1305 tag - data tampered")
	end

	bSuccess, sDecrypted = pcall(self.CHACHA20.decrypt, sKey, 1, sNonce, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decrypt content, error: " .. tostring(sDecrypted))
	end

	return sDecrypted
end

function LIBRARY:Decompress(sContent)
	assert(IsTable(self.LZW) and IsFunction(self.LZW.decompress),	"[LIB-CODEC] LZW.decompress missing")
	assert(IsString(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.LZW.decompress, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decompress content, error: " .. tostring(sContent))
	end

	return sContent
end

function LIBRARY:Base64Encode(sContent, sTag, sNonce)
	assert(IsTable(self.BASE64) and IsFunction(self.BASE64.encode),	"[LIB-CODEC] BASE64.encode missing")
	assert(IsString(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.BASE64.encode, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.BASE64.encode, sTag)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64 tag, error: " .. tostring(sTag))
	end

	bSuccess, sNonce	= pcall(self.BASE64.encode, sNonce)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64 nonce, error: " .. tostring(sNonce))
	end

	return sContent, sTag, sNonce
end

function LIBRARY:Base64Decode(sContent, sTag, sNonce)
	assert(IsTable(self.BASE64) and IsFunction(self.BASE64.decode),	"[LIB-CODEC] BASE64.decode missing")
	assert(IsString(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.BASE64.decode, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.BASE64.decode, sTag)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64 tag, error: " .. tostring(sTag))
	end

	bSuccess, sNonce	= pcall(self.BASE64.decode, sNonce)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64 nonce, error: " .. tostring(sNonce))
	end

	return sContent, sTag, sNonce
end

function LIBRARY:Encode(tData)
	assert(IsTable(self.JSON) and IsFunction(self.JSON.encode),	"[LIB-CODEC] JSON.encode missing")
	assert(IsTable(tData) and self:IsValidData(tData),			"[LIB-CODEC] Invalid data")

	local bSuccess, sJSONContent;

	bSuccess, tData.CONTENT = pcall(self.JSON.encode, tData.CONTENT)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode content")
	end

	if tData.COMPRESSED then
		tData.CONTENT = self:Compress(tData.CONTENT)
	end

	if tData.ENCRYPTED then
		tData.NONCE								= "\x00\x00\x00\x00\x00\x00\x00\x4a\x00\x00\x00\x00"
		tData.CONTENT, tData.TAG				= self:Encrypt(tData.CONTENT, self.KEY, tData.NONCE)
		tData.CONTENT, tData.TAG, tData.NONCE	= self:Base64Encode(tData.CONTENT, tData.TAG, tData.NONCE)
	end

	bSuccess, sJSONContent = pcall(self.JSON.encode, tData)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode data JSON, error: " .. tostring(sJSONContent))
	end

	return sJSONContent
end

function LIBRARY:Decode(sData)
	assert(IsTable(self.JSON) and IsFunction(self.JSON.decode),	"[LIB-CODEC] JSON.decode missing")
	assert(IsString(sData),										"[LIB-CODEC] Data must be string")

	local bSuccess, tData;

	bSuccess, tData = pcall(self.JSON.decode, sData)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode JSON, error: " .. tostring(tData))
	end

	if not self:IsValidData(tData) then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Invalid data format")
	end

	if tData.ENCRYPTED then
		tData.CONTENT, tData.TAG, tData.NONCE	= self:Base64Decode(tData.CONTENT, tData.TAG, tData.NONCE)
		tData.CONTENT							= self:Decrypt(tData.CONTENT, self.KEY, tData.NONCE, tData.TAG)
	end

	if tData.COMPRESSED then
		tData.CONTENT = self:Decompress(tData.CONTENT)
	end

	bSuccess, tData.CONTENT = pcall(self.JSON.decode, tData.CONTENT)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode JSON content")
	end

	return tData.ID, tData.CONTENT
end