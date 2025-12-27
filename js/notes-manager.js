// Менеджер заметок
const NotesManager = (function() {
    // Получение всех заметок
    function getNotes() {
        try {
            return JSON.parse(localStorage.getItem('user_notes')) || [];
        } catch (error) {
            console.error('Ошибка загрузки заметок:', error);
            return [];
        }
    }

    // Сохранение всех заметок
    function saveNotes(notes) {
        try {
            localStorage.setItem('user_notes', JSON.stringify(notes));
        } catch (error) {
            console.error('Ошибка сохранения заметок:', error);
        }
    }

    // Получение заметки для конкретного элемента
    function getNote(itemId, itemType) {
        const notes = getNotes();
        return notes.find(note => 
            note.itemId === itemId && note.itemType === itemType
        );
    }

    // Проверка наличия заметки
    function hasNote(itemId, itemType) {
        return !!getNote(itemId, itemType);
    }

    // Сохранение заметки
    function saveNote(itemId, itemType, text) {
        const notes = getNotes();
        const existingIndex = notes.findIndex(note => 
            note.itemId === itemId && note.itemType === itemType
        );
        
        const noteData = {
            itemId,
            itemType,
            text,
            date: new Date().toISOString()
        };
        
        if (existingIndex > -1) {
            notes[existingIndex] = noteData;
        } else {
            notes.push(noteData);
        }
        
        saveNotes(notes);
    }

    // Удаление заметки
    function deleteNote(itemId, itemType) {
        const notes = getNotes();
        const filteredNotes = notes.filter(note => 
            !(note.itemId === itemId && note.itemType === itemType)
        );
        saveNotes(filteredNotes);
    }

    // Получение количества заметок
    function getNotesCount() {
        return getNotes().length;
    }

    // Получение заметок по типу
    function getNotesByType(itemType) {
        const notes = getNotes();
        return notes.filter(note => note.itemType === itemType);
    }

    return {
        getNotes,
        getNote,
        hasNote,
        saveNote,
        deleteNote,
        getNotesCount,
        getNotesByType
    };
})();