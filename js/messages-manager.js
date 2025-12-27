// Менеджер сообщений
const MessagesManager = (function() {
    // Получение всех сообщений
    function getMessages() {
        try {
            return JSON.parse(localStorage.getItem('user_messages')) || [];
        } catch (error) {
            console.error('Ошибка загрузки сообщений:', error);
            return [];
        }
    }

    // Сохранение всех сообщений
    function saveMessages(messages) {
        try {
            localStorage.setItem('user_messages', JSON.stringify(messages));
        } catch (error) {
            console.error('Ошибка сохранения сообщений:', error);
        }
    }

    // Получение сообщения для конкретного элемента
    function getMessage(itemId, itemType) {
        const messages = getMessages();
        return messages.find(msg => 
            msg.itemId === itemId && msg.itemType === itemType
        );
    }

    // Проверка наличия сообщения
    function hasMessage(itemId, itemType) {
        return !!getMessage(itemId, itemType);
    }

    // Сохранение сообщения
    function saveMessage(itemId, itemType, text) {
        const messages = getMessages();
        const existingIndex = messages.findIndex(msg => 
            msg.itemId === itemId && msg.itemType === itemType
        );
        
        const messageData = {
            itemId,
            itemType,
            text,
            date: new Date().toISOString(),
            read: false
        };
        
        if (existingIndex > -1) {
            messages[existingIndex] = messageData;
        } else {
            messages.push(messageData);
        }
        
        saveMessages(messages);
    }

    // Удаление сообщения
    function deleteMessage(itemId, itemType) {
        const messages = getMessages();
        const filteredMessages = messages.filter(msg => 
            !(msg.itemId === itemId && msg.itemType === itemType)
        );
        saveMessages(filteredMessages);
    }

    // Отметка как прочитанного
    function markAsRead(itemId, itemType) {
        const messages = getMessages();
        const messageIndex = messages.findIndex(msg => 
            msg.itemId === itemId && msg.itemType === itemType
        );
        
        if (messageIndex > -1) {
            messages[messageIndex].read = true;
            saveMessages(messages);
        }
    }

    // Получение количества непрочитанных сообщений
    function getUnreadCount() {
        const messages = getMessages();
        return messages.filter(msg => !msg.read).length;
    }

    return {
        getMessages,
        getMessage,
        hasMessage,
        saveMessage,
        deleteMessage,
        markAsRead,
        getUnreadCount
    };
})();